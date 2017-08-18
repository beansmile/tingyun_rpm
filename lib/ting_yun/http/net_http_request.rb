require 'ting_yun/http/generic_request'
module TingYun
  module Http
    class NetHttpRequest < GenericRequest
      def initialize(connection, request)
        @connection = connection
        @request = request
      end

      def type
        'Net::HTTP'
      end

      def from
        "net%2Fhttp"
      end

      def host
        if hostname = self['host']
          hostname.split(':').first
        else
          @connection.address
        end
      end

      def method
        @request.method
      end

      def [](key)
        @request[key]
      end

      def []=(key, value)
        @request[key] = value
      end

      def uri
        case @request.path
          when /^https?:\/\//
            URI(@request.path)
          else
            scheme = @connection.use_ssl? ? 'https' : 'http'
            URI("#{scheme}://#{@connection.address}:#{@connection.port}#{@request.path}")
        end
      end
    end
  end
end

