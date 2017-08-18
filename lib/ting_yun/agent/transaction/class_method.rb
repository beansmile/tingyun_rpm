# encoding: utf-8

module TingYun
  module Agent
    class Transaction
    # web transaction
      module ClassMethod

        def tl_current
          TingYun::Agent::TransactionState.tl_get.current_transaction
        end

        def metrics
          txn = tl_current
          txn && txn.metrics
        end


        def recording_web_transaction? #THREAD_LOCAL_ACCESS
          txn = tl_current
          txn && txn.web_category?(txn.category)
        end

        # See TingYun::Agent.notice_error for options and commentary
        def notice_error(e, options={})
          state = TingYun::Agent::TransactionState.tl_get
          txn = state.current_transaction
          if txn
            txn.exceptions.notice_error(e, options)
          elsif TingYun::Agent.instance
            TingYun::Agent.instance.error_collector.notice_error(e, options)
          end
        end


        def stop(state, end_time = Time.now, summary_metric_names=[])

          txn = state.current_transaction

          unless txn
            TingYun::Agent.logger.error("Failed during Transaction.stop because there is no current transaction")
            return
          end

          nested_frame = txn.frame_stack.pop

          if txn.frame_stack.empty?
            txn.stop(state, end_time, nested_frame, summary_metric_names)
            state.reset
          else
            nested_name = nested_transaction_name(nested_frame.name)

            if nested_name.start_with?(MIDDLEWARE_PREFIX)
              summary_metrics = MIDDLEWARE_SUMMARY_METRICS
            else
              summary_metrics = EMPTY_SUMMARY_METRICS
            end
            summary_metrics = summary_metric_names unless summary_metric_names.empty?

            TingYun::Agent::MethodTracerHelpers.trace_execution_scoped_footer(
                state,
                nested_frame.start_time.to_f,
                nested_name,
                summary_metrics,
                nested_frame,
                NESTED_TRACE_STOP_OPTIONS,
                end_time.to_f)

          end

          :transaction_stopped
        rescue => e
          state.reset
          TingYun::Agent.logger.error("Exception during Transaction.stop", e)
          nil
        end

        def wrap(state, name, category, options = {}, summary_metrics=[])
          Transaction.start(state, category, options.merge(:transaction_name => name))

          begin
            # We shouldn't raise from Transaction.start, but only wrap the yield
            # to be absolutely sure we don't report agent problems as app errors
            yield
          rescue => e
            Transaction.notice_error(e)
            raise e
          ensure
            # when kafka consumer in task, drop original web_action
            Transaction.stop(state, Time.now, summary_metrics) if state.current_transaction
          end
        end


        def start(state, category, options)
          category ||= :controller
          txn = state.current_transaction
          if txn
            txn.create_nested_frame(state, category, options)
          else
            txn = start_new_transaction(state, category, options)
          end

          # merge params every step into here
          txn.attributes.merge_request_parameters(options[:filtered_params])

          txn
        rescue => e
          TingYun::Agent.logger.error("Exception during Transaction.start", e)
        end

        def start_new_transaction(state, category, options)
          txn = Transaction.new(category, state.client_transaction_id, options)
          state.reset(txn)
          txn.start(state)
          txn
        end

        def nested_transaction_name(name)
          if name.start_with?(CONTROLLER_PREFIX) || name.start_with?(BACKGROUND_PREFIX)
            "#{SUBTRANSACTION_PREFIX}#{name}"
          else
            name
          end
        end

        def set_default_transaction_name(name, category = nil, node_name = nil) #THREAD_LOCAL_ACCESS
          txn  = tl_current
          name = txn.make_transaction_name(name, category)
          txn.name_last_frame(node_name || name)
          txn.set_default_transaction_name(name, category)
        end

        def set_frozen_transaction_name!(name) #THREAD_LOCAL_ACCESS
          txn  = tl_current
          txn.frozen_name = name
        end
      end
    end
  end
end