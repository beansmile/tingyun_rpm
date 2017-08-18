# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

# This module was normalize the date encode
require 'ting_yun/support/language_support'


module TingYun
  module Support
    module Serialize
      module EncodingNormalizer
        def self.normalize_object(object)
          case object
            when String
              normalize_string(object)
            when Symbol
              normalize_string(object.to_s)
            when Array
              return object if object.empty?
              object.map { |x| normalize_object(x) }
            when Hash
              return object if object.empty?
              hash = {}
              object.each do |k, v|
                k = normalize_string(k) if k.is_a?(String)
                k = normalize_string(k.to_s) if k.is_a?(Symbol)
                hash[k] = normalize_object(v)
              end
              hash
            else
              object
          end
        end
        def self.normalize_string(str)
          @normalizer ||= choose_normalizer
          @normalizer.normalize(str)
        end

        def self.choose_normalizer
          if TingYun::Support::LanguageSupport.supports_string_encodings?
            EncodingNormalizer
          else
            IconvNormalizer
          end
        end

        module EncodingNormalizer
          def self.normalize(str)
            encoding = str.encoding
            if (encoding == Encoding::UTF_8 || encoding == Encoding::ISO_8859_1) && str.valid_encoding?
              return str
            end
            # If the encoding is not valid, or it's ASCII-8BIT, we know conversion to
            # UTF-8 is likely to fail, so treat it as ISO-8859-1 (byte-preserving).
            normalized = str.dup
            if encoding == Encoding::ASCII_8BIT || !str.valid_encoding?
              normalized.force_encoding(Encoding::ISO_8859_1)
            else
              # Encoding is valid and non-binary, so it might be cleanly convertible
              # to UTF-8. Give it a try and fall back to ISO-8859-1 if it fails.
              begin
                normalized.encode!(Encoding::UTF_8)
              rescue
                normalized.force_encoding(Encoding::ISO_8859_1)
              end
            end
            normalized
          end
        end


        module IconvNormalizer
          def self.normalize(raw_string)
            if @iconv.nil?
              require 'iconv'
              @iconv = Iconv.new('utf-8', 'iso-8859-1')
            end
            @iconv.iconv(raw_string)
          end
        end
      end
    end
  end
end