# encoding: utf-8
require 'ting_yun/middleware/agent_middleware'
require 'ting_yun/instrumentation/support/javascript_instrumentor'
require 'ting_yun/support/coerce'

module TingYun
  class BrowserMonitoring < AgentMiddleware

    include TingYun::Support::Coerce

    CONTENT_TYPE        = 'Content-Type'.freeze
    TEXT_HTML           = 'text/html'.freeze
    CONTENT_DISPOSITION = 'Content-Disposition'.freeze
    ATTACHMENT          = 'attachment'.freeze

    SCAN_LIMIT          = 64_000

    TITLE_END           = '</title>'.freeze
    TITLE_END_CAPITAL   = '</TITLE>'.freeze
    HEAD_END            = '<head>'.freeze
    HEAD_END_CAPITAL    = '<HEAD>'.freeze

    GT                  = '>'.freeze




    def traced_call(env)
      result = @app.call(env)   # [status, headers, response]

      if should_instrument?(env, result[0], result[1])
        if rum_enable? # unsupport insert script
          if TingYun::Agent.config[:'nbs.rum.mix_enabled']
            result[1]["Set-Cookie"] = "TINGYUN_DATA=#{manufacture_cookie}"
            env[ALREADY_INSTRUMENTED_KEY] = true
            result
          else
            js_to_inject = TingYun::Instrumentation::Support::JavascriptInstrument.browser_timing_header
            if (js_to_inject != '')
              response_string = auto_instrument_source(result[2], js_to_inject)

              env[ALREADY_INSTRUMENTED_KEY] = true
              if response_string
                response = Rack::Response.new(response_string, result[0], result[1])
                response.finish
              else
                result
              end
            else
              result
            end
          end
        else
          result
        end
      else
        result
      end
    end

    ALREADY_INSTRUMENTED_KEY = "tingyun.browser_monitoring_already_instrumented"

    def should_instrument?(env, status, headers)
      status == 200 &&
          is_ajax?(env) &&
          !env[ALREADY_INSTRUMENTED_KEY] &&
          is_html?(headers) &&
          !is_attachment?(headers)
    end

    def is_html?(headers)
      headers[CONTENT_TYPE] && headers[CONTENT_TYPE].include?(TEXT_HTML)
    end

    def is_ajax?(env)
      env["HTTP_X_REQUESTED_WITH"].nil?
    end

    def is_attachment?(headers)
      headers[CONTENT_DISPOSITION] && headers[CONTENT_DISPOSITION].include?(ATTACHMENT)
    end

    def rum_enable?
      TingYun::Agent.config[:'nbs.rum.enabled']
    end

    def manufacture_cookie
      state = TingYun::Agent::TransactionState.tl_get
      timings = state.timings
      "%7B%22id%22%3A%22#{TingYun::Support::Coerce.url_encode(TingYun::Agent.config[:tingyunIdSecret].to_s)}%22%2C%22n%22%3A%22#{TingYun::Support::Coerce.url_encode(state.transaction_name.to_s)}%22%2C%22tid%22%3A%22#{state.trace_id}%22%2C%22q%22%3A#{timings.queue_time_in_millis}%2C%22a%22%3A#{timings.app_time_in_millis}%7D"
    end
    def browser_timing_config(state)
      timings = state.timings

      data = {
          :id => TingYun::Agent.config[:tingyunIdSecret],
          :n => state.transaction_name ,
          :a => timings.app_time_in_millis,
          :q => timings.queue_time_in_millis,
          :tid => state.trace_id
      }
      data
    end


    def auto_instrument_source(response, js_to_inject)
      source = gather_source(response)
      close_old_response(response)
      return nil unless source

      beginning_of_source = source[0..SCAN_LIMIT]
      insertion_index = find_tag_end(beginning_of_source)

      if insertion_index
        source = source[0...insertion_index] <<
            js_to_inject <<
            source[insertion_index..-1]
      else
        TingYun::Agent.logger.debug "Skipping RUM instrumentation. Could not properly determine location to inject script."
      end

      source
    rescue => e
      TingYun::Agent.logger.debug "Skipping RUM instrumentation on exception.", e
      nil
    end

    def gather_source(response)
      source = nil
      response.each {|fragment| source ? (source << fragment.to_s) : (source = fragment.to_s)}
      source
    end

    def close_old_response(response)
      if response.respond_to?(:close)
        response.close
      end
    end

    def find_tag_end(beginning_of_source)
      tag_end = beginning_of_source.index(TITLE_END) ||
          beginning_of_source.index(HEAD_END) ||
          beginning_of_source.index(TITLE_END_CAPITAL) ||
          beginning_of_source.index(HEAD_END_CAPITAL)

      beginning_of_source.index(GT, tag_end) + 1 if tag_end
    end
  end
end
