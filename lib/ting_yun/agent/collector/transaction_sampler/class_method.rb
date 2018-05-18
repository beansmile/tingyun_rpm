# encoding: utf-8

module TingYun
  module Agent
    module Collector
      class TransactionSampler
        module ClassMethod


          def notice_push_frame(state, time=Time.now.to_f)
            builder = state.transaction_sample_builder
            return unless builder
            builder.trace_entry(time)
          end

          # Informs the transaction sample builder about the end of a traced frame
          def notice_pop_frame(state, frame, time = Time.now.to_f, klass_name=nil, error = nil)
            builder = state.transaction_sample_builder
            return unless builder
            builder.trace_exit(frame, time, klass_name, error)
          end


          def on_start_transaction(state, time)
            if TingYun::Agent.config[:'nbs.action_tracer.enabled']
              state.transaction_sample_builder ||= TingYun::Agent::TransactionSampleBuilder.new(time)
            else
              state.transaction_sample_builder = nil
            end
          end

          # Attaches an SQL query on the current transaction trace node.
          # @param sql [String] the SQL query being recorded
          # @param config [Object] the driver configuration for the connection
          # @param duration [Float] number of seconds the query took to execute
          # @param explainer [Proc] for internal use only - 3rd-party clients must
          #                         not pass this parameter.
          # duration{:type => sec}
          def notice_sql(sql, config, duration, state=nil, explainer=nil, binds=[], name="SQL")
            # some statements (particularly INSERTS with large BLOBS
            # may be very large; we should trim them to a maximum usable length
            state ||= TingYun::Agent::TransactionState.tl_get
            builder = state.transaction_sample_builder
            if state.sql_recorded?
              statement = TingYun::Agent::Database::Statement.new(sql, config, explainer, binds, name)
              action_tracer_segment(builder, statement, duration, :sql)
            end
          end

          # duration{:type => sec}
          def notice_nosql(key, duration) #THREAD_LOCAL_ACCESS
            builder = tl_builder
            action_tracer_segment(builder, key, duration, :key)
          end

          # duration{:type => sec}
          def notice_nosql_statement(statement, duration) #THREAD_LOCAL_ACCESS
            builder = tl_builder
            action_tracer_segment(builder, statement, duration, :statement)
          end





          MAX_DATA_LENGTH = 16384
          # This method is used to record metadata into the currently
          # active node like a sql query, memcache key, or Net::HTTP uri
          #
          # duration is milliseconds, float value.
          # duration{:type => sec}
          def action_tracer_segment(builder, message, duration, key)
            return unless builder
            node = builder.current_node
            if node
              if key == :sql
                statement = node[:sql]
                if statement && !statement.sql.empty?
                  statement.sql = truncate_message(statement.sql + "\n#{message.sql}") if statement.sql.length <= MAX_DATA_LENGTH
                else
                  # message is expected to have been pre-truncated by notice_sql
                  node[:sql] =  message
                end
              else
                node[key] = truncate_message(message)
              end
              append_backtrace(node, duration)
            end
          end

          # Truncates the message to `MAX_DATA_LENGTH` if needed, and
          # appends an ellipsis because it makes the trucation clearer in
          # the UI
          def truncate_message(message)
            size = MAX_DATA_LENGTH - 4
            if message.length > size
              message.slice!(size..message.length)
              message << '...'
            else
              message
            end
          end


          # Appends a backtrace to a node if that node took longer
          # than the specified duration
          def append_backtrace(node, duration)
            if duration*1000 >= Agent.config[:'nbs.action_tracer.stack_trace_threshold']
              trace = caller.reject! { |t| t.include?('tingyun_rpm') }
              trace = trace.first(20)
              node[:stacktrace] = trace
            end
          end

          def add_node_info(params)
            builder = tl_builder
            return unless builder
            params.each { |k,v| builder.current_node.instance_variable_set(('@'<<k.to_s).to_sym, v)  }
          end

          def tl_builder
            TingYun::Agent::TransactionState.tl_get.transaction_sample_builder
          end

        end
      end
    end
  end
end

