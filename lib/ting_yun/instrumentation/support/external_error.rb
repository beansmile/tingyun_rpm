# encoding: utf-8
require 'ting_yun/agent'
require 'ting_yun/support/exception'


module TingYun
  module Instrumentation
    module Support
      module Variables
        attr_accessor :tingyun_code, :tingyun_klass, :tingyun_external, :tingyun_trace
      end
      module ExternalError

        module_function

        def capture_exception(response,request)
          if response && response.code =~ /^[4,5][0-9][0-9]$/ && response.code!='401'
            e = TingYun::Support::Exception::InternalServerError.new("#{response.code}: #{response.message}")
            klass = "External/#{request.uri.to_s.gsub('/','%2F')}/#{request.from}"
            set_attributes(e, klass, response.code)

            TingYun::Agent.notice_error(e)
          end
        end

        def handle_error(e,klass)
          case e
            when Errno::ECONNREFUSED
              set_attributes(e, klass, 902)
            when SocketError
              set_attributes(e, klass, 901)
            when OpenSSL::SSL::SSLError
              set_attributes(e, klass, 908)
            when Timeout::Error
              set_attributes(e, klass, 903)
            else
              set_attributes(e, klass, 1000)
          end

          TingYun::Agent.notice_error(e)
        end

        def set_attributes(exception, klass, code)
          exception.instance_exec {extend TingYun::Instrumentation::Support::Variables}
          begin
            exception.tingyun_code = code
            exception.tingyun_klass = klass
            exception.tingyun_external = true
            trace = caller.reject! { |t| t.include?('tingyun_rpm') }
            trace = trace.first(20)
            exception.tingyun_trace = trace
          rescue => e
            TingYun::Agent.logger.warn("Failed to set attributes for : #{exception}: ", e)
          end
        end

      end
    end
  end
end
