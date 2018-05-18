# encoding: utf-8
require 'ting_yun/http/abstract_request'

    module TingYun
      module Http


    class CurbRequest
      CURB = 'Curb'.freeze
      LHOST = 'host'.freeze
      UHOST = 'Host'.freeze

      def initialize( curlobj )
        @curlobj = curlobj
      end

      def type
        CURB
      end

      def from
        "curb%2Fhttp"
      end

      def host_from_header
        self[LHOST] || self[UHOST]
      end

      def host
        host_from_header || self.uri.host
      end

      def method
        @curlobj._ty_http_verb
      end

      def []( key )
        @curlobj.headers[ key ]
      end

      def []=( key, value )
        @curlobj.headers[ key ] = value
      end

      def uri
        @uri ||= TingYun::Agent::HTTPClients::URIUtil.parse_and_normalize_url(@curlobj.url)
      end
    end


    class CurbResponse < AbstractRequest
      def initialize(curlobj)
        @headers = {}
        @curlobj = curlobj
      end

      def [](key)
        @headers[ key.downcase ]
      end

      def to_hash
        @headers.dup
      end

      def append_header_data( data )
        key, value = data.split( /:\s*/, 2 )
        @headers[ key.downcase ] = value
        @curlobj._ty_header_str ||= ''
        @curlobj._ty_header_str << data
      end

    end


  end
end
