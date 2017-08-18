# encoding: utf-8

require 'ting_yun/agent/database'
require 'ting_yun/agent/transaction/transaction_state'


require 'ting_yun/agent/collector/sql_sampler/transaction_sql_data'
require 'ting_yun/agent/collector/sql_sampler/slow_sql'
require 'ting_yun/agent/collector/sql_sampler/sql_trace'
module TingYun
  module Agent
    module Collector
      # This class contains the logic of recording slow SQL traces, which may
      # represent multiple aggregated SQL queries.
      #
      # A slow SQL trace consists of a collection of SQL instrumented SQL queries
      # that all normalize to the same text. For example, the following two
      # queries would be aggregated together into a single slow SQL trace:
      #
      #   SELECT * FROM table WHERE id=42
      #   SELECT * FROM table WHERE id=1234
      #
      # Each slow SQL trace keeps track of the number of times the same normalized
      # query was seen, the min, max, and total time spent executing those
      # queries, and an example backtrace from one of the aggregated queries.

      class SqlSampler

        MAX_SAMPLES = 10

        attr_reader :sql_traces

        def initialize
          @sql_traces = {}
          @samples_lock = Mutex.new
        end

        def self.on_start_transaction(state, uri)
          return unless TingYun::Agent::Database.sql_sampler_enabled?

          state.init_sql_transaction(::TingYun::Agent::Collector::TransactionSqlData.new(uri))
        end

        # duration{:type => sec}
        def self.notice_sql(sql, metric_name, config, duration, state=nil, explainer=nil, binds=[], name="SQL") #THREAD_LOCAL_ACCESS sometimes
          start_time = Time.now.to_f
          state ||= TingYun::Agent::TransactionState.tl_get
          data = state.sql_sampler_transaction_data
          return unless data
          threshold = duration*1000
          if threshold > TingYun::Agent.config[:'nbs.action_tracer.slow_sql_threshold'] && state.sql_recorded?
            backtrace = ''
            if threshold > TingYun::Agent.config[:'nbs.action_tracer.stack_trace_threshold']
              backtrace = caller.reject! { |t| t.include?('tingyun_rpm') }
              backtrace = backtrace.first(20).join("\n")
            end
            statement = TingYun::Agent::Database::Statement.new(sql, config, explainer, binds, name)
            data.sql_data << ::TingYun::Agent::Collector::SlowSql.new(statement, metric_name, duration, start_time, backtrace)
          end
        end

        def on_finishing_transaction(state, name)
          return unless TingYun::Agent::Database.sql_sampler_enabled?

          transaction_sql_data = state.sql_sampler_transaction_data
          return unless transaction_sql_data

          transaction_sql_data.set_transaction_name(name)

          save_slow_sql(transaction_sql_data)
        end

        def save_slow_sql(data)
          size = data.sql_data.size
          if size > 0
            @samples_lock.synchronize do
              ::TingYun::Agent.logger.debug "Examining #{size} slow transaction sql statement(s)"
              save data
            end
          end
        end

        def save (transaction_sql_data)
          action_metric_name = transaction_sql_data.metric_name
          uri                = transaction_sql_data.uri

          transaction_sql_data.sql_data.each do |sql_item|
            normalized_sql = sql_item.normalize
            sql_trace = @sql_traces[normalized_sql]
            if sql_trace
              sql_trace.aggregate(sql_item, action_metric_name, uri)
            else
              if has_room?
                @sql_traces[normalized_sql] = ::TingYun::Agent::Collector::SqlTrace.new(normalized_sql, sql_item, action_metric_name, uri)
              else
                min, max = @sql_traces.minmax_by { |(_, trace)| trace.max_call_time }
                if max.last.max_call_time < sql_item.duration
                  @sql_traces.delete(min.first)
                  @sql_traces[normalized_sql] = ::TingYun::Agent::Collector::SqlTrace.new(normalized_sql, sql_item, action_metric_name, uri)
                end
              end
            end
          end
        end

        # this should always be called under the @samples_lock
        def has_room?
          @sql_traces.size < MAX_SAMPLES
        end


        def harvest!
          return [] unless TingYun::Agent::Database.sql_sampler_enabled?
          slowest = []
          @samples_lock.synchronize do
            slowest = @sql_traces.values
            @sql_traces = {}
          end
          slowest.each {|trace| trace.prepare_to_send }
          slowest
        end

        def reset!
          @samples_lock.synchronize do
            @sql_traces = {}
          end
        end

        def merge!(sql_traces)
          @samples_lock.synchronize do
            sql_traces.each do |trace|
              existing_trace = @sql_traces[trace.sql]
              if existing_trace
                existing_trace.aggregate(trace.slow_sql, trace.path, trace.url)
              else
                @sql_traces[trace.sql] = trace
              end
            end
          end
        end
      end

    end
  end
end
