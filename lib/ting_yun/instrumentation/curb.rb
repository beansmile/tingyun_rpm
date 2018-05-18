TingYun::Support::LibraryDetection.defer do
  named :curb

  CURB_MIN_VERSION = Gem::Version.new("0.8.1")

  depends_on do
    defined?(::Curl) && defined?(::Curl::CURB_VERSION) &&
        Gem::Version.new(::Curl::CURB_VERSION) >= CURB_MIN_VERSION
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Curb instrumentation'
    require 'ting_yun/agent/cross_app/cross_app_tracing'
    require 'ting_yun/agent/method_tracer_helpers'
    require 'ting_yun/http/curb_wrappers'
  end



  executes do
    class Curl::Easy

      attr_accessor :_ty_instrumented,
                    :_ty_http_verb,
                    :_ty_header_str,
                    :_ty_original_on_header,
                    :_ty_original_on_complete,
                    :_ty_serial

      # We have to hook these three methods separately, as they don't use
      # Curl::Easy#http
      def http_head_with_tingyun(*args, &blk)
        self._ty_http_verb = :HEAD
        http_head_without_tingyun(*args, &blk)
      end
      alias_method :http_head_without_tingyun, :http_head
      alias_method :http_head, :http_head_with_tingyun

      def http_post_with_tingyun(*args, &blk)
        self._ty_http_verb = :POST
        http_post_without_tingyun(*args, &blk)
      end
      alias_method :http_post_without_tingyun, :http_post
      alias_method :http_post, :http_post_with_tingyun

      def http_put_with_tingyun(*args, &blk)
        self._ty_http_verb = :PUT
        http_put_without_tingyun(*args, &blk)
      end
      alias_method :http_put_without_tingyun, :http_put
      alias_method :http_put, :http_put_with_tingyun


      # Hook the #http method to set the verb.
      def http_with_tingyun( verb )
        self._ty_http_verb = verb.to_s.upcase
        http_without_tingyun( verb )
      end

      alias_method :http_without_tingyun, :http
      alias_method :http, :http_with_tingyun


      # Hook the #perform method to mark the request as non-parallel.
      def perform_with_tingyun
        self._ty_serial = true
        perform_without_tingyun
      end

      alias_method :perform_without_tingyun, :perform
      alias_method :perform, :perform_with_tingyun

      # We override this method in order to ensure access to header_str even
      # though we use an on_header callback
      def header_str_with_tingyun
        if self._ty_serial
          self._ty_header_str
        else
          # Since we didn't install a header callback for a non-serial request,
          # just fall back to the original implementation.
          header_str_without_tingyun
        end
      end

      alias_method :header_str_without_tingyun, :header_str
      alias_method :header_str, :header_str_with_tingyun
    end # class Curl::Easy

    class Curl::Multi
    

      # Add CAT with callbacks if the request is serial
      def add_with_tingyun(curl) #THREAD_LOCAL_ACCESS
        if curl.respond_to?(:_ty_serial) && curl._ty_serial
          hook_pending_request(curl) if TingYun::Agent.tl_is_execution_traced?
        end

        return add_without_tingyun( curl )
      end

      alias_method :add_without_tingyun, :add
      alias_method :add, :add_with_tingyun


      # Trace as an External/Multiple call if the first request isn't serial.
      def perform_with_tingyun(&blk)
        return perform_without_tingyun if
            self.requests.first &&
                self.requests.first.respond_to?(:_ty_serial) &&
                self.requests.first._ty_serial

        TingYun::Agent::MethodTracerHelpers.trace_execution_scoped("External/Multiple/Curb::Multi/perform") do
          perform_without_tingyun(&blk)
        end
      end

      alias_method :perform_without_tingyun, :perform
      alias_method :perform, :perform_with_tingyun


      # Instrument the specified +request+ (a Curl::Easy object) and set up cross-application
      # tracing if it's enabled.
      def hook_pending_request(request) #THREAD_LOCAL_ACCESS
        wrapped_request, wrapped_response = wrap_request(request)
        state = TingYun::Agent::TransactionState.tl_get
        t0 = Time.now.to_f
        node = TingYun::Agent::CrossAppTracing.start_trace(state, t0, wrapped_request)

        unless request._ty_instrumented
          install_header_callback( request, wrapped_response )
          install_completion_callback( request, t0, node, wrapped_request, wrapped_response )
          request._ty_instrumented = true
        end
      rescue => err
        TingYun::Agent.logger.error("Untrapped exception", err)
      end


      # Create request and response adapter objects for the specified +request+
      def wrap_request(request)
        return TingYun::Http::CurbRequest.new(request),
            TingYun::Http::CurbResponse.new(request)
      end



      # Install a callback that will record the response headers to enable
      # CAT linking
      def install_header_callback( request, wrapped_response )
        original_callback = request.on_header
        request._ty_original_on_header = original_callback
        request._ty_header_str = ''
        request.on_header do |header_data|
          wrapped_response.append_header_data( header_data )

          if original_callback
            original_callback.call( header_data )
          else
            header_data.length
          end
        end
      end

      # Install a callback that will finish the trace.
      def install_completion_callback( request, t0, segment, wrapped_request, wrapped_response )
        original_callback = request.on_complete
        request._ty_original_on_complete = original_callback
        request.on_complete do |finished_request|
          begin
            TingYun::Agent::CrossAppTracing.finish_trace(TingYun::Agent::TransactionState.tl_get,t0, segment, wrapped_request, wrapped_response )
          ensure
            # Make sure the existing completion callback is run, and restore the
            # on_complete callback to how it was before.
            original_callback.call( finished_request ) if original_callback
            remove_instrumentation_callbacks( request )
          end
        end
      end

      def remove_instrumentation_callbacks( request )
        request.on_complete(&request._ty_original_on_complete)
        request.on_header(&request._ty_original_on_header)
        request._ty_instrumented = false
      end

    end # class Curl::Multi

  end


end