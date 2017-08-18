# encoding: utf-8
require 'ting_yun/agent'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/support/quantile_p2'

module TingYun
  module Agent
    module MethodTracerHelpers

      extend self

      def log_errors(code_area)
        yield
      rescue => e
        ::TingYun::Agent.logger.error("Caught exception in #{code_area}.", e)
        ::TingYun::Agent.notice_error(e, method: code_area, path: "ting_yun/agent/method_tracer_helpers")
      end

      def trace_execution_scoped_header(state, t0)
        log_errors(:trace_execution_scoped_header) do
          stack = state.traced_method_stack
          stack.push_frame(state, :method_tracer, t0)
        end
      end

      def trace_execution_scoped_footer(state, t0, first_name, metric_names, expected_frame, options, t1=Time.now.to_f, klass_name=nil)
        log_errors(:trace_execution_scoped_footer) do
          if expected_frame
            stack = state.traced_method_stack
            create_metrics = options.has_key?(:metric) ? options[:metric] : true
            frame = stack.pop_frame(state, expected_frame, first_name, t1, create_metrics, klass_name)

            if create_metrics
              duration = (t1 - t0)*1000
              exclusive = duration - frame.children_time
              if duration < 0
                ::TingYun::Agent.logger.log_once(:warn, "metric_duration_negative:#{first_name}",
                                                 "Metric #{first_name} has negative duration: #{duration} ms")
              end
              if exclusive < 0
                ::TingYun::Agent.logger.log_once(:warn, "metric_exclusive_negative:#{first_name}",
                                                 "Metric #{first_name} has negative exclusive time: duration = #{duration} ms, child_time = #{frame.children_time}")
              end
              record_metrics(state, first_name, metric_names, duration, exclusive, options)
              if first_name.start_with?('WebAction')
                state.current_transaction.base_quantile_hash[first_name] = duration
              end
            end
          end
        end
      end

      def record_metrics(state, first_name, other_names, duration, exclusive, options)
        record_scoped_metric = options.has_key?(:scoped_metric) ? options[:scoped_metric] : true
        stat_engine = TingYun::Agent.instance.stats_engine
        if record_scoped_metric
          stat_engine.record_scoped_and_unscoped_metrics(state, first_name, other_names, duration, exclusive)
        else
          metrics = [first_name].concat(other_names)
          stat_engine.record_unscoped_metrics(state, metrics, duration, exclusive)
        end
      end

      def  trace_execution_scoped(metric_names, options={}, callback = nil, klass_name=nil) #THREAD_LOCAL_ACCESS
        state = TingYun::Agent::TransactionState.tl_get

        metric_names = Array(metric_names)
        first_name   = metric_names.shift
        return yield unless first_name

        start_time = Time.now.to_f
        expected_scope = trace_execution_scoped_header(state, start_time)

        begin
          yield
        ensure
          elapsed_time = (Time.now.to_f - start_time)
          if callback
            callback.call(elapsed_time)
          end
          trace_execution_scoped_footer(state, start_time, first_name, metric_names, expected_scope, options, Time.now.to_f, klass_name)
        end
      end



    end
  end
end
