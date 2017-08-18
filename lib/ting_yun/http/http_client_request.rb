require 'ting_yun/http/generic_request'
module TingYun
  module Http
    class HttpClientRequest < GenericRequest
      attr_reader :method, :header

      def initialize(proxy, *args, &block)
        @method, @uri, @query, @body, @header = args
        @proxy = proxy
        @block = block
      end

      def type
        'HTTPClient'
      end

      def from
        "http_client%2Fhttp"
      end

      def [](key)
        @header[key]
      end

      def []=(key, value)
        @header[key] = value
      end

      def uri
        return @uri if @uri.scheme && @uri.host && @uri.port
        URI("#{@proxy.scheme.downcase}://#{@proxy.host}:#{@proxy.port}#{@uri}")
      end

      def args
        return @method, @uri, @query, @body, @header
      end
    end
  end
end