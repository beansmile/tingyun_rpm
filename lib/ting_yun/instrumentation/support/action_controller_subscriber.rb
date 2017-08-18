# encoding: utf-8

require 'ting_yun/instrumentation/support/queue_time'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/instrumentation/support/evented_subscriber'
require 'ting_yun/agent/transaction'
require 'ting_yun/instrumentation/support/split_controller'
require 'ting_yun/instrumentation/support/parameter_filtering'

module TingYun
  module Instrumentation
    module Rails
      class ActionControllerSubscriber < TingYun::Instrumentation::Support::EventedSubscriber
        def start(name, id, payload) #THREAD_LOCAL_ACCES
          state = TingYun::Agent::TransactionState.tl_get
          request = state.current_transaction.request_attributes rescue nil
          event = ControllerEvent.new(name, Time.now, nil, id, payload, request)
          push_event(event)
          # if state.execution_traced?
          start_transaction(state, event)
            # end
        rescue => e
          log_notification_error(e, name, 'start')
        end

        def finish(name, id, payload) #THREAD_LOCAL_ACCESS

          event = pop_event(id)
          event.payload.merge!(payload)

          state = TingYun::Agent::TransactionState.tl_get


          stop_transaction(state)
        rescue => e
          log_notification_error(e, name, 'finish')
        end

        def start_transaction(state, event)
          params = TingYun::Instrumentation::Support::ParameterFiltering.flattened_filter_request_parameters(event.payload[:params])
          TingYun::Agent::Transaction.start(state, :controller,
                                            :request => event.request,
                                            :filtered_params => params,
                                            :apdex_start_time => event.queue_start,
                                            :transaction_name => event.metric_name)
        end

        def stop_transaction(state)
          # txn = state.current_transaction
          TingYun::Agent::Transaction.stop(state)
        end


      end

      class ControllerEvent < TingYun::Instrumentation::Support::Event

        include TingYun::Instrumentation::Support::SplitController

        attr_accessor :parent
        attr_reader :queue_start, :request

        def initialize(name, start, ending, transaction_id, payload, request)
          # We have a different initialize parameter[[j]] list, so be explicit
          super(name, start, ending, transaction_id, payload, nil)

          @request = request
          @controller_class = payload[:controller].split('::') \
            .inject(Object) { |m, o| m.const_get(o) }

          if request && request.respond_to?(:env)
            @queue_start = TingYun::Instrumentation::Support::QueueTime.parse_frontend_timestamp(request.env, self.time)
          end
        end

        def metric_name
          if find_rule(method, uri, request.header, params)
            @metric_name =  "WebAction/Rails/#{namespace}/#{name(uri, request.header, params, request.cookie)}"
          else
            if TingYun::Agent.config[:'nbs.auto_action_naming']
              @metric_name ||= "WebAction/Rails/#{metric_path}%2F#{metric_action}"
            else
              "WebAction/URI/#{uri[1..-1].gsub(/\//,'%2F')}"
            end
          end
        end

        def method
          payload[:params]['_method'].upcase rescue nil ||  payload[:method]
        end

        def params
          payload[:params]
        end

        def metric_path
          @controller_class.controller_path
        end

        def metric_class
          payload[:controller]
        end

        def metric_action
          payload[:action]
        end

        #expect the params
        def uri
          path.split('?').first
        end
        #contain the params

        def path
          payload[:path]
        end

        def to_s
          "#<TingYun::Instrumentation::ControllerEvent:#{object_id} name: \"#{name}\" id: #{transaction_id} payload: #{payload}}>"
        end
      end
    end
  end
end
