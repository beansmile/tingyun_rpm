# encoding: utf-8

require 'ting_yun/instrumentation/support/evented_subscriber'
require 'ting_yun/agent/method_tracer_helpers'
require 'ting_yun/agent/transaction'

module TingYun
  module Instrumentation
    module Rails
      class ActionCableSubscriber < TingYun::Instrumentation::Support::EventedSubscriber

        PERFORM_ACTION = 'perform_action.action_cable'.freeze

        def start (name, id, payload) #THREAD_LOCAL_ACCESS
          state = TingYun::Agent::TransactionState.tl_get
          return unless state.execution_traced?
          event = super
          if event.name == PERFORM_ACTION
            start_transaction state, event
          else
            start_recording_metrics state, event
          end
        rescue => e
          log_notification_error e, name, 'start'
        end

        def finish (name, id, payload) #THREAD_LOCAL_ACCESS
          state = TingYun::Agent::TransactionState.tl_get
          return unless state.execution_traced?
          event = super
          notice_error payload if payload.key? :exception
          if event.name == PERFORM_ACTION
            finish_transaction state
          else
            stop_recording_metrics state, event
          end
        rescue => e
          log_notification_error e, name, 'finish'
        end

        private

        def start_transaction state, event
          TingYun::Agent::Transaction.start(state, :action_cable, :transaction_name => transaction_name_from_event(event))
        end

        def finish_transaction state
          TingYun::Agent::Transaction.stop(state)
        end

        def start_recording_metrics state, event
          expected_scope = TingYun::Agent::MethodTracerHelpers::trace_execution_scoped_header(state, event.time.to_f)
          event.payload[:expected_scope] =  expected_scope
        end

        def stop_recording_metrics state, event
          expected_scope = event.payload.delete :expected_scope
          metric_name = metric_name_from_event event
          TingYun::Agent::MethodTracerHelpers::trace_execution_scoped_footer(state, event.time.to_f, metric_name, [], expected_scope, {:metric => true}, event.end.to_f)
        end

        def transaction_name_from_event event
          "WebAction/ActionCable/#{event.payload[:channel_class]}%2F#{event.payload[:action]}"
        end

        def metric_name_from_event event
          "ActionCable/#{event.payload[:channel_class]}%2F#{action_name_from_event(event)}"
        end

        DOT_ACTION_CABLE = ".action_cable".freeze
        EMPTY_STRING = "".freeze

        def action_name_from_event event
          event.name.gsub DOT_ACTION_CABLE, EMPTY_STRING
        end

        def notice_error payload
          TingYun::Agent.notice_error payload[:exception_object]
        end
      end
    end
  end
end
