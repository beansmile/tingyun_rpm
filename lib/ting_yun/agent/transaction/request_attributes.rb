# encoding: utf-8

require 'ting_yun/support/http_clients/uri_util'

module TingYun
  module Agent
    class Transaction
      class RequestAttributes

        attr_reader :request_path, :referer, :accept, :content_length, :host,
                    :port, :user_agent, :request_method, :header, :cookie

        HTTP_ACCEPT_HEADER_KEY = 'HTTP_ACCEPT'.freeze

        def initialize request
          @header = request.env
          @request_path = path_from_request request
          @referer = referer_from_request request
          @accept = attribute_from_env request, HTTP_ACCEPT_HEADER_KEY
          @content_length = content_length_from_request request
          @host = attribute_from_request request, :host
          @port = port_from_request request
          @user_agent = attribute_from_request request, :user_agent
          @request_method = attribute_from_request request, :request_method
          @cookie = set_cookie(request)
        end

        def assign_agent_attributes(attributes)
          attributes.add_agent_attribute :request_path, request_path
          attributes.add_agent_attribute :referer, referer
          attributes.add_agent_attribute :accept, accept
          attributes.add_agent_attribute :contentLength, content_length
          attributes.add_agent_attribute :host, host
          attributes.add_agent_attribute :port, port
          attributes.add_agent_attribute :userAgent, user_agent
          attributes.add_agent_attribute :method, request_method
        end


        private

        # Make a safe attempt to get the referer from a request object, generally successful when
        # it's a Rack request.

        def referer_from_request request
          if referer = attribute_from_request(request, :referer)
            TingYun::Agent::HTTPClients::URIUtil.strip_query_string referer.to_s
          end
        end

        ROOT_PATH = "/".freeze

        def path_from_request request
          path = attribute_from_request(request, :path) || ''
          path = TingYun::Agent::HTTPClients::URIUtil.strip_query_string(path)
          path.empty? ? ROOT_PATH : path
        end

        def content_length_from_request request
          if content_length = attribute_from_request(request, :content_length)
            content_length.to_i
          end
        end

        def port_from_request request
          if port = attribute_from_request(request, :port)
            port.to_i
          end
        end

        def attribute_from_request request, attribute_method
          if request.respond_to? attribute_method
            request.send(attribute_method)
          end
        end

        def attribute_from_env request, key
          if env = attribute_from_request(request, :env)
            env[key]
          end
        end

        def set_cookie(request)
          cookie = {}
          _c = attribute_from_env(request, 'HTTP_COOKIE')
          _c.split(/\s*;\s*/).each do |i|
            _k, _v = i.split('=')
            if _k && _v
              cookie[_k] = _v
            end
          end if _c
          cookie
        end

      end
    end
  end
end
