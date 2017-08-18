 # encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require 'base64'
require 'zlib'
require 'ting_yun/support/serialize/json_wrapper'

module TingYun
  module Support
    module Serialize
      module Encoders
        module Identity
          def self.encode(data, opts=nil)
            data
          end
        end

        module Compressed
          def self.encode(data, opts=nil)
            Zlib::Deflate.deflate(data, Zlib::DEFAULT_COMPRESSION)
          end
        end

        module Base64CompressedJSON
          def self.encode(data, opts={})
            normalize_encodings = if opts[:skip_normalization]
                                    false
                                  else
                                    TingYun::Agent.config[:normalize_json_string_encodings]
                                  end
            json = JSONWrapper.dump(data, :normalize => normalize_encodings)
            Base64.encode64(Compressed.encode(json))
          end
        end
        module CompressedJSON
          def self.encode(data, opts={})
            normalize_encodings = if opts[:skip_normalization]
                                    false
                                  else
                                    TingYun::Agent.config[:normalize_json_string_encodings]
                                  end
            json = JSONWrapper.dump(data, :normalize => normalize_encodings)
            Compressed.encode(json)
          end
        end

        module Json
          def self.encode(data, opts={})
            normalize_encodings = if opts[:skip_normalization]
                                    false
                                  else
                                    TingYun::Agent.config[:normalize_json_string_encodings]
                                  end
            json = JSONWrapper.dump(data, :normalize => normalize_encodings)
            return json
          end
        end
      end
    end
  end
end
