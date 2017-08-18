# encoding: utf-8
require 'ting_yun/agent/cross_app/inbound_request_monitor'
require 'ting_yun/agent/cross_app/cross_app_tracing'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/agent'
require 'ting_yun/support/serialize/json_wrapper'


module TingYun
  module Agent
    class CrossAppMonitor < TingYun::Agent::InboundRequestMonitor


      TY_ID_HEADER = 'HTTP_X_TINGYUN_ID'.freeze
      TY_DATA_HEADER = 'X-Tingyun-Tx-Data'.freeze


      def on_finished_configuring(events)
        register_event_listeners(events)
      end


      # Expected sequence of events:
      #   :before_call will save our cross application request id to the thread
      #   :after_call will write our response headers/metrics and clean up the thread
      def register_event_listeners(events)
        TingYun::Agent.logger.debug("Wiring up Cross Application Tracing to events after finished configuring")

        events.subscribe(:cross_app_before_call) do |env| #THREAD_LOCAL_ACCESS
          if TingYun::Agent::CrossAppTracing.cross_app_enabled?
            state = TingYun::Agent::TransactionState.tl_get
            state.save_referring_transaction_info(env[TY_ID_HEADER].split(';')) if env[TY_ID_HEADER]
          end
        end

        events.subscribe(:cross_app_after_call) do |_status_code, headers, _body| #THREAD_LOCAL_ACCESS
          insert_response_header(headers) if TingYun::Agent::CrossAppTracing.cross_app_enabled?
        end

      end


      def insert_response_header(response_headers)
        state = TingYun::Agent::TransactionState.tl_get
        if state.same_account?
          txn = state.current_transaction
          if txn
            # set_response_headers
            response_headers[TY_DATA_HEADER] = TingYun::Support::Serialize::JSONWrapper.dump build_payload(state)
            TingYun::Agent.logger.debug("now,cross app will send response_headers  #{response_headers[TY_DATA_HEADER]}")
          end
        end
      end


      def build_payload(state)
        timings = state.timings

        payload = {
          :id => TingYun::Agent.config[:tingyunIdSecret].split('|')[1],
          :action => state.transaction_name,
          :trId => state.trace_id,
          :time => {
            :duration => timings.app_time_in_millis,
            :qu => timings.queue_time_in_millis,
            :db => timings.sql_duration,
            :ex => timings.external_duration,
            :rds => timings.rds_duration,
            :mc => timings.mc_duration,
            :mon => timings.mon_duration,
            :code => timings.app_execute_duration
          }
        }
        payload[:tr] = 1 if timings.slow_action_tracer?
        payload[:r] = state.client_req_id unless state.client_req_id.nil?
        payload
      end

    end
  end
end