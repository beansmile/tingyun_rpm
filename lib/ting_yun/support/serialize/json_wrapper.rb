# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require 'ting_yun/support/serialize/encoding_normalizer'
require 'ting_yun/support/language_support'
require 'ting_yun/support/hash_extensions'

module TingYun
  module Support
    module Serialize
      class JSONWrapper
        def self.load_native_json
          begin
            require 'json' unless defined?(::JSON)

            # yajl's replacement methods on ::JSON override both dump and generate.
            # Because stdlib dump just calls generate, we end up calling into yajl
            # when we don't want to. As such, we use generate directly instead of
            # dump, although we have to fuss with defaults to make that ok.
            generate_method = ::JSON.method(:generate)
            if ::JSON.respond_to?(:dump_default_options)
              options = ::JSON.dump_default_options
            else
              # These were the defaults from json 1.1.9 up to 1.6.1
              options = {:allow_nan => true, :max_nesting => false, :quirks_mode => true}
            end
            @dump_method = Proc.new do |obj|
              generate_method.call(obj, options)
            end

            @load_method = ::JSON.method(:load)
            @backend_name = :json
            return true
          rescue StandardError, ScriptError => err
            TingYun::Agent.logger.debug "%p while loading JSON library: %s" % [err, err.message] if defined?(TingYun::Agent) && TingYun::Agent.respond_to?(:logger)
          end
        end

        def self.load_ok_json
          require 'ting_yun/support/serialize/ok_json'
          @load_method = OkJson.method(:decode)
          @dump_method = OkJson.method(:encode)
          @backend_name = :ok_json
        end

        load_native_json or load_ok_json

        def self.usable_for_collector_serialization?
          @backend_name == :json
        end

        def self.backend_name
          @backend_name
        end

        def self.supports_normalization?
          TingYun::Support::LanguageSupport.supports_string_encodings?
        end

        def self.dump(object, options={})
          object = normalize(object) if options[:normalize]
          # ok_json doesn't handle symbol keys, so we must stringify them before encoding
          object = TingYun::Support::HashExtensions.stringify_keys_in_object(object) if backend_name == :ok_json
          @dump_method.call(object)
        end

        def self.load(string)
          @load_method.call(string)
        end

        def self.normalize(o)
          TingYun::Support::Serialize::EncodingNormalizer.normalize_object(o)
        end
      end
    end
  end
end

