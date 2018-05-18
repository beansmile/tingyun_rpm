# encoding: utf-8

TingYun::Support::LibraryDetection.defer do

  named :net_http

  depends_on do
    defined?(Net) && defined?(Net::HTTP) && !::TingYun::Agent.config[:disable_net_http]
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Net instrumentation'
    require 'ting_yun/agent/cross_app/cross_app_tracing'
    require 'ting_yun/http/net_http_request'
    require 'ting_yun/instrumentation/support/external_error'
  end

  executes do
    class Net::HTTP
      def request_with_tingyun_trace(request, *args, &block)
        tingyun_request = TingYun::Http::NetHttpRequest.new(self, request)

        TingYun::Agent::CrossAppTracing.tl_trace_http_request(tingyun_request) do
          TingYun::Agent.disable_all_tracing do
            request_without_tingyun_trace(request, *args, &block )
          end
        end
      end

      alias :request_without_tingyun_trace :request
      alias :request :request_with_tingyun_trace


      # class << self
      #   def get_response_with_tingyun(uri_or_host, path = nil, port = nil, &block)
      #     begin
      #       get_response_without_tingyun(uri_or_host, path , port , &block)
      #     rescue => e
      #       ::TingYun::Instrumentation::Support::ExternalError.handle_error(e, "External/#{uri_or_host.to_s.gsub(/\/\z/,'').gsub('/','%2F')}/net%2Fhttp")
      #       raise e
      #     end
      #   end
      #   alias get_response_without_tingyun get_response
      #   alias get_response get_response_with_tingyun
      #
      #   def start_with_tingyun(address, *arg, &block)
      #     begin
      #       start_without_tingyun(address, *arg, &block)
      #     rescue => e
      #       # ::TingYun::Instrumentation::Support::ExternalError.handle_error(e, "External/#{address.to_s.gsub(/\/\z/,'').gsub('/','%2F')}/net%2Fhttp")
      #       raise e
      #     end
      #   end
      #   alias :start_without_tingyun :start
      #   alias :start :start_with_tingyun
      #
      # end
    end
  end
end