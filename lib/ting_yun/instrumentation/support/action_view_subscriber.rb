# encoding: utf-8


require 'ting_yun/instrumentation/support/evented_subscriber'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/agent'

module TingYun
  module Instrumentation
    module Rails
      class ActionViewSubscriber < TingYun::Instrumentation::Support::EventedSubscriber

        def start(name, id, payload) #THREAD_LOCAL_ACCESS
          event = RenderEvent.new(name, Time.now, nil, id, payload)
          push_event(event)

          state = TingYun::Agent::TransactionState.tl_get

          if event.recordable?
            stack = state.traced_method_stack
            event.frame = stack.push_frame(state, :action_view, event.time.to_f)
          end
        rescue => e
          log_notification_error(e, name, 'start')
        end

        def finish(name, id, payload) #THREAD_LOCAL_ACCESS
          event = pop_event(id)

          state = TingYun::Agent::TransactionState.tl_get

          if event.recordable?
            stack = state.traced_method_stack
            frame = stack.pop_frame(state, event.frame, event.metric_name, event.end.to_f)
            record_metrics(event, frame)
          end
        rescue => e
          log_notification_error(e, name, 'finish')
        end

        def record_metrics(event, frame)
          exclusive = event.duration - frame.children_time
          TingYun::Agent.instance.stats_engine.tl_record_scoped_and_unscoped_metrics(
              event.metric_name, nil, event.duration, exclusive)
        end
      end

      class RenderEvent < TingYun::Instrumentation::Support::Event

        def recordable?
          name[0] == '!' ||
              metric_name == 'View/text template/Rendering' ||
              metric_name == "View/#{::TingYun::Agent::UNKNOWN_METRIC}/Partial"
        end

        def metric_name
          if parent && (payload[:virtual_path] ||
              (parent.payload[:identifier] =~ /template$/))
            return parent.metric_name
          elsif payload.key?(:virtual_path)
            identifier = payload[:virtual_path]
          else
            identifier = payload[:identifier]
          end

          # memoize
          @metric_name ||= "View/#{metric_path(identifier)}/#{metric_action(name)}"
          @metric_name
        end

        def metric_path(identifier)
          if identifier == nil
            'file'
          elsif identifier =~ /template$/
            identifier
          elsif (parts = identifier.split('/')).size > 1
            parts[-2..-1].join('/')
          else
            ::TingYun::Agent::UNKNOWN_METRIC
          end
        end

        def metric_action(name)
          case name
            when /render_template.action_view$/ then
              'Rendering'
            when 'render_partial.action_view' then
              'Partial'
            when 'render_collection.action_view' then
              'Partial'
          end
        end
      end
    end
  end
end