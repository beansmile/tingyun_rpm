# encoding: utf-8
require 'ting_yun/http/abstract_request'

module TingYun
  module Http

  class TyphoeusHTTPResponse
        def initialize(response)
          @response = response
        end

        def [](key)
          unless headers.nil?
            result = headers[key]

            # Typhoeus 0.5.3 has a bug where asking the headers hash for a
            # non-existent header will return the hash itself, not what we want.
            result == headers ? nil : result
          end
        end

        def to_hash
          hash = {}
          headers.each do |(k,v)|
            hash[k] = v
          end
          hash
        end

        private

        def headers
          @response.headers
        end
      end

      class TyphoeusHTTPRequest < AbstractRequest
        def initialize(request)
          @request = request
          @uri = case request.url
            when ::URI then request.url
            else TingYun::Agent::HTTPClients::URIUtil.parse_and_normalize_url(request.url)
            end
        end

        TYPHOEUS = "Typhoeus".freeze

        def type
          TYPHOEUS
        end
        def from
          "typhoeus%2Fhttp"
        end

        LHOST = 'host'.freeze
        UHOST = 'Host'.freeze

        def host_from_header
          self[LHOST] || self[UHOST]
        end

        def host
          host_from_header || @uri.host
        end

        GET = 'GET'.freeze

        def method
          (@request.options[:method] || GET).to_s.upcase
        end

        def [](key)
          return nil unless @request.options && @request.options[:headers]
          @request.options[:headers][key]
        end

        def []=(key, value)
          @request.options[:headers] ||= {}
          @request.options[:headers][key] = value
        end

        def uri
          @uri
        end
      end
    end

end
