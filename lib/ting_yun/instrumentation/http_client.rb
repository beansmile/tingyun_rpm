# encoding: utf-8
module TingYun::Instrumentation::HttpClient

  HTTPCLIENT_MIN_VERSION = '2.1.5'.freeze

  def self.version_support?
    TingYun::Support::VersionNumber.new(HTTPClient::VERSION) >= TingYun::Support::VersionNumber.new(HTTPCLIENT_MIN_VERSION)
  end
end

TingYun::Support::LibraryDetection.defer do

  named :http_client

  depends_on do
    defined?(::HTTPClient) && TingYun::Instrumentation::HttpClient.version_support?
  end

  depends_on do
    !::TingYun::Agent.config[:disable_http_client]
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing HTTPClient instrumentation'
    require 'ting_yun/agent/cross_app/cross_app_tracing'
    require 'ting_yun/http/http_client_request'
    require 'ting_yun/instrumentation/support/external_error'
  end

  executes do
    ::HTTPClient.class_eval do

      if private_method_defined? :follow_redirect
        private
        alias_method :follow_redirect_without_tingyun_trace, :follow_redirect

        def follow_redirect(*args, &block)
          begin
            follow_redirect_without_tingyun_trace(*args, &block)
          rescue => e
            args[1] = (::Module.private_method_defined? :to_resource_url) ? to_resource_url(args[1]) : urify(args[1])
            proxy = no_proxy?(args[1]) ? nil : @proxy
            tingyun_request = TingYun::Http::HttpClientRequest.new(proxy, *args, &block)
            ::TingYun::Instrumentation::Support::ExternalError.handle_error(e, "External/#{tingyun_request.uri.to_s.gsub(/\/\z/,'').gsub('/','%2F')}/#{tingyun_request.from}")
            raise e
          end
        end
      end

      private
      alias :do_request_without_tingyun_trace :do_request

      def do_request(*args, &block)
        proxy = no_proxy?(args[1]) ? nil : @proxy
        tingyun_request = TingYun::Http::HttpClientRequest.new(proxy, *args, &block)
        TingYun::Agent::CrossAppTracing.tl_trace_http_request(tingyun_request) do
          TingYun::Agent.disable_all_tracing do
            do_request_without_tingyun_trace(*tingyun_request.args, &block)
          end
        end
      end
    end

    ::HTTP::Message.class_eval do
      def message
        header.reason_phrase
      end
    end
  end
end