TingYun::Support::LibraryDetection.defer do
  named :typhoeus


  depends_on do
    defined?(Typhoeus) && defined?(Typhoeus::VERSION)
  end

  depends_on do
    TingYun::Instrumentation::TyphoeusTracing.is_supported_version?
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Typhoeus instrumentation'
    require 'ting_yun/agent/cross_app/cross_app_tracing'
    require 'ting_yun/http/typhoeus_wrappers'
    require 'ting_yun/agent/method_tracer_helpers'
  end

  # Basic request tracing
  executes do
    Typhoeus.before do |request|
      TingYun::Instrumentation::TyphoeusTracing.trace(request)

      # Ensure that we always return a truthy value from the before block,
      # otherwise Typhoeus will bail out of the instrumentation.
      true
    end
  end

  # Apply single TT node for Hydra requests until async support
  executes do
    class Typhoeus::Hydra


      def run_with_tingyun(*args)
        TingYun::Agent::MethodTracerHelpers.trace_execution_scoped("External/Multiple/Typhoeus::Hydra/run") do
          run_without_tingyun(*args)
        end
      end

      alias run_without_tingyun run
      alias run run_with_tingyun
    end
  end


end


module TingYun::Instrumentation::TyphoeusTracing

  EARLIEST_VERSION = TingYun::Support::VersionNumber.new("0.5.3")

  def self.is_supported_version?
    TingYun::Support::VersionNumber.new(Typhoeus::VERSION) >= TingYun::Instrumentation::TyphoeusTracing::EARLIEST_VERSION
  end

  def self.request_is_hydra_enabled?(request)
    request.respond_to?(:hydra) && request.hydra
  end

  def self.trace(request)
    if TingYun::Agent.tl_is_execution_traced? && !request_is_hydra_enabled?(request)
      wrapped_request = ::TingYun::Http::TyphoeusHTTPRequest.new(request)
      state = TingYun::Agent::TransactionState.tl_get
      t0 = Time.now.to_f
      segment = TingYun::Agent::CrossAppTracing.start_trace(state, t0, wrapped_request)
      request.on_complete do
        wrapped_response = ::TingYun::Http::TyphoeusHTTPResponse.new(request.response)
        TingYun::Agent::CrossAppTracing.finish_trace(TingYun::Agent::TransactionState.tl_get,t0, segment, wrapped_request, wrapped_response )
      end
    end
  end
end
