TingYun::Support::LibraryDetection.defer do
  named :excon

  EXCON_MIN_VERSION = Gem::Version.new("0.10.1")
  EXCON_MIDDLEWARE_MIN_VERSION = Gem::Version.new("0.19.0")

  depends_on do
    defined?(::Excon) && defined?(::Excon::VERSION)
  end

  executes do
    excon_version = Gem::Version.new(::Excon::VERSION)
    if excon_version >= EXCON_MIN_VERSION
      install_excon_instrumentation(excon_version)
    else
      ::TingYun::Agent.logger.warn("Excon instrumentation requires at least version #{EXCON_MIN_VERSION}")
    end
  end

  def install_excon_instrumentation(excon_version)
    require 'ting_yun/agent/cross_app/cross_app_tracing'
    require 'ting_yun/http/excon_wrappers'

    if excon_version >= EXCON_MIDDLEWARE_MIN_VERSION
      install_middleware_excon_instrumentation
    else
      install_legacy_excon_instrumentation
    end
  end

  def install_middleware_excon_instrumentation
    ::TingYun::Agent.logger.info 'Installing middleware-based Excon instrumentation'
    defaults = Excon.defaults

    if defaults[:middlewares]
      defaults[:middlewares] << ::Excon::Middleware::TingYunCrossAppTracing
    else
      ::TingYun::Agent.logger.warn("Did not find :middlewares key in Excon.defaults, skipping Excon instrumentation")
    end
  end

  def install_legacy_excon_instrumentation
    ::TingYun::Agent.logger.info 'Installing legacy Excon instrumentation'

    ::Excon::Connection.install_tingyun_instrumentation
  end


end

module ::Excon
  class Connection
    def tingyun_connection_params
      (@connection || @data)
    end

    def tingyun_resolved_request_params(request_params)
      resolved = tingyun_connection_params.merge(request_params)
      resolved[:headers] = resolved[:headers].merge(request_params[:headers] || {})
      resolved
    end

    def request_with_tingyun_trace(params, &block)
      orig_response = nil
      resolved_params = tingyun_resolved_request_params(params)
      wrapped_request = ::TingYun::Http::ExconHTTPRequest.new(resolved_params)
      ::TingYun::Agent::CrossAppTracing.trace_http_request(wrapped_request) do
        orig_response = request_without_tingyun_trace(resolved_params, &block)
        ::TingYun::Http::ExconHTTPResponse.new(orig_response)
      end
      orig_response
    end

    def self.install_tingyun_instrumentation
      alias request_without_tingyun_trace request
      alias request request_with_tingyun_trace
    end
  end

  module Middleware
    class TingYunCrossAppTracing
      TRACE_DATA_IVAR = :@tingyun_trace_data

      def initialize(stack)
        @stack = stack
      end

      def request_call(datum)
        begin
          # Only instrument this request if we haven't already done so, because
          # we can get request_call multiple times for requests marked as
          # :idempotent in the options, but there will be only a single
          # accompanying response_call/error_call.
          if datum[:connection] && !datum[:connection].instance_variable_get(TRACE_DATA_IVAR)
            wrapped_request = ::TingYun::Http::ExconHTTPRequest.new(datum)
            state = TingYun::Agent::TransactionState.tl_get
            t0 = Time.now.to_f
            node = TingYun::Agent::CrossAppTracing.start_trace(state, t0, wrapped_request)

            datum[:connection].instance_variable_set(TRACE_DATA_IVAR, [t0, node, wrapped_request])
          end
        rescue => e
          TingYun::Agent.logger.debug(e)
        end
        @stack.request_call(datum)
      end

      def response_call(datum)
        finish_trace(datum)
        @stack.response_call(datum)
      end

      def error_call(datum)
        finish_trace(datum)
        @stack.error_call(datum)
      end

      def finish_trace(datum)
        trace_data = datum[:connection] && datum[:connection].instance_variable_get(TRACE_DATA_IVAR)
        if trace_data
          datum[:connection].instance_variable_set(TRACE_DATA_IVAR, nil)
          t0, segment, wrapped_request = trace_data
          if datum[:response]
            wrapped_response = ::TingYun::Http::ExconHTTPResponse.new(datum[:response])
          end
          TingYun::Agent::CrossAppTracing.finish_trace(TingYun::Agent::TransactionState.tl_get,t0, segment, wrapped_request, wrapped_response )
        end
      end
    end
  end
end
