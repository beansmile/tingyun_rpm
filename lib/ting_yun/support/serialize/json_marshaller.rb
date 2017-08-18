# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require 'ting_yun/support/serialize/marshaller'
require 'ting_yun/support/serialize/json_wrapper'
require 'ting_yun/support/version_number'


module TingYun
  module Support
    module Serialize
      # Marshal collector protocol with JSON when available
      class JsonMarshaller < Marshaller
        def initialize
          TingYun::Agent.logger.debug "Using JSON marshaller (#{JSONWrapper.backend_name})"
          unless self.class.is_supported?
            TingYun::Agent.logger.warn "The JSON marshaller in use (#{JSONWrapper.backend_name}) is not recommended. Ensure the 'json' gem is available in your application for better performance."
          end
          warn_for_yajl
        end

        OK_YAJL_VERSION = TingYun::Support::VersionNumber.new("1.2.1")

        def warn_for_yajl
          if defined?(::Yajl)
            require 'yajl/version'
            if VersionNumber.new(::Yajl::VERSION) < OK_YAJL_VERSION
              ::TingYun::Agent.logger.warn "Detected yajl-ruby version #{::Yajl::VERSION} which can cause segfaults with TingYun_rpm's thread profiling features. We strongly recommend you upgrade to the latest yajl-ruby version available."
            end
          end
        rescue => err
          ::TingYun::Agent.logger.warn "Failed trying to watch for problematic yajl-ruby version.", err
        end

        def dump(ruby, opts={})
          prepared = prepare(ruby, opts)

          if opts[:skip_normalization]
            normalize_encodings = false
          else
            normalize_encodings = TingYun::Agent.config[:normalize_json_string_encodings]
          end

          JSONWrapper.dump(prepared, :normalize => normalize_encodings)
        end

        def load(data)
          if data.nil? || data.empty?
            ::TingYun::Agent.logger.error "Empty JSON response from collector: '#{data.inspect}'"
            return nil
          end

          return_value(JSONWrapper.load(data))
        rescue => e
          ::TingYun::Agent.logger.debug "#{e.class.name} : #{e.message} encountered loading collector response: #{data}"
          raise
        end

        def format
          'json'
        end

        def self.is_supported?
          JSONWrapper.usable_for_collector_serialization?
        end

        def self.human_readable?
          true # for some definitions of 'human'
        end
      end
    end
  end
end
