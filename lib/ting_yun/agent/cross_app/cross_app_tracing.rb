# encoding: utf-8

require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/agent/transaction'
require 'ting_yun/support/http_clients/uri_util'
require 'ting_yun/support/serialize/json_wrapper'
require 'ting_yun/instrumentation/support/external_error'
require 'ting_yun/agent/collector/transaction_sampler'


module TingYun
  module Agent
    module CrossAppTracing

      extend ::TingYun::Instrumentation::Support::ExternalError

      # Exception raised if there is a problem with cross app transactions.
      class Error < RuntimeError; end

      # The cross app id header for "outgoing" calls

      TY_ID_HEADER = 'X-Tingyun-Id'.freeze
      TY_DATA_HEADER = 'X-Tingyun-Tx-Data'.freeze


      module_function


      def tl_trace_http_request(request)
        state = TingYun::Agent::TransactionState.tl_get
        return yield unless state.execution_traced?
        return yield unless state.current_transaction #如果还没有创建Transaction，就发生跨应用，就直接先跳过跟踪。

        t0 = Time.now.to_f
        begin
          node = start_trace(state, t0, request)
          response = yield
          capture_exception(response, request)
        ensure
          finish_trace(state, t0, node, request, response)
        end
        return response
      end

      def start_trace(state, t0, request)
        inject_request_headers(state, request) if cross_app_enabled?
        stack = state.traced_method_stack
        node = stack.push_frame(state, :http_request, t0)

        return node
      end

      def finish_trace(state, t0, node, request, response)

        t1 = Time.now.to_f
        duration = (t1- t0) * 1000
        state.timings.external_duration = duration

        begin
          if request
            cross_app = response_is_cross_app?(response)

            metrics = metrics_for(request)
            node_name = metrics.pop
            tx_data = TingYun::Support::Serialize::JSONWrapper.load(get_ty_data_header(response).gsub("'",'"')) || {}
            # net_block_duration = tx_data["time"]? duration - tx_data["time"]["duration"]- tx_data["time"]["qu"] : duration
            # net_block_duration = duration if net_block_duration < 0
            ::TingYun::Agent.instance.stats_engine.record_scoped_and_unscoped_metrics(state, node_name, metrics, duration)
            if cross_app
              _duration =  tx_data["time"]["duration"] + tx_data["time"]["qu"] + 0.1
              metrics_cross_app = metrics_for_cross_app(request, response)
              txn = state.current_transaction
              txn.metrics.record_scoped(metrics_cross_app.pop, duration, _duration)
              txn.metrics.record_unscoped(metrics_cross_app, _duration)
            end

            if node
              node.name = node_name
              add_transaction_trace_info(request, response, cross_app, tx_data)
            end
          end
        rescue => err
          TingYun::Agent.logger.error "Uncaught exception while finishing an HTTP request trace", err
        ensure
          if node
            stack = state.traced_method_stack
            stack.pop_frame(state, node, node_name, t1)
          end
        end
      end


      def add_transaction_trace_info(request, response, cross_app, tx_data)
        state = TingYun::Agent::TransactionState.tl_get
        ::TingYun::Agent::Collector::TransactionSampler.add_node_info(:uri => TingYun::Agent::HTTPClients::URIUtil.filter_uri(request.uri))
        if cross_app
          ::TingYun::Agent::Collector::TransactionSampler.tl_builder.set_txId_and_txData(state.client_transaction_id || state.request_guid, tx_data)
        end
      end


      def metrics_for_cross_app(request, response)
        my_data =  TingYun::Support::Serialize::JSONWrapper.load get_ty_data_header(response).gsub("'",'"')
        metrics = ["ExternalTransaction/NULL/#{my_data["id"]}",
                   "ExternalTransaction/http/#{my_data["id"]}"]
        metrics << "ExternalTransaction/#{request.uri.to_s.gsub(/\/\z/,'').gsub('/','%2F')}/#{my_data["id"]}%2F#{my_data["action"].to_s.gsub(/\/\z/,'')}"
      end

      def metrics_for(request)
        metrics = [ "External/NULL/ALL" ]
        if TingYun::Agent::Transaction.recording_web_transaction?
          metrics << "External/NULL/AllWeb"
        else
          metrics << "External/NULL/AllBackground"
        end
        metrics << "External/#{request.uri.to_s.gsub(/\/\z/,'').gsub('/','%2F')}/#{request.from}"
        return metrics
      end



      def cross_app_enabled?
        TingYun::Agent.config[:tingyunIdSecret] && TingYun::Agent.config[:tingyunIdSecret].size > 0 &&
            TingYun::Agent.config[:'nbs.action_tracer.enabled'] &&
            TingYun::Agent.config[:'nbs.transaction_tracer.enabled']
      end

      # Inject the X-Process header into the outgoing +request+.
      def inject_request_headers(state, request)
        cross_app_id  = TingYun::Agent.config[:tingyunIdSecret]

        request[TY_ID_HEADER] = "#{cross_app_id};c=1;x=#{state.request_guid}"
      end

      # Returns +true+ if Cross Application Tracing is enabled, and the given +response+
      # has the appropriate headers.
      def response_is_cross_app?( response )
        return false unless response
        return false unless cross_app_enabled?
        return false if get_ty_data_header(response).empty?

        return true
      end



      def get_ty_data_header(response)
        if defined?(::HTTP) && defined?(::HTTP::Message) && response.class == ::HTTP::Message
          response.header[TY_DATA_HEADER].first.to_s rescue ""
        else
          response[TY_DATA_HEADER].to_s rescue ""
        end
      end
    end
  end
end
