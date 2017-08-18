# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require 'zlib'
require 'net/https'
require 'net/http'
require 'ting_yun/ting_yun_service/ssl'
require 'ting_yun/ting_yun_service/request'
require 'ting_yun/ting_yun_service/connection'
require 'ting_yun/support/exception'

module TingYun
  class TingYunService
    module Http

      include Ssl
      include Request
      include Connection

      def remote_method_uri(method)
        params = {'licenseKey'=> @license_key,'version' => @data_version}
        raise ::TingYun::Support::Exception::AppSessionKeyError.new("@appSessionKey is asked when the upload-method happen") if method==:upload && @appSessionKey.nil?
        params[:appSessionKey] = @appSessionKey

        uri = "/" + method.to_s
        uri << '?' + params.map do |k,v|
          next unless v
          "#{k}=#{v}"
        end.compact.join('&')
        uri
      end

      # Decompresses the response from the server, if it is gzip
      # encoded, otherwise returns it verbatim
      def decompress_response(response)
        if response['content-encoding'] == 'gzip'
          Zlib::GzipReader.new(StringIO.new(response.body)).read
        else
          response.body
        end
      end
    end
  end
end