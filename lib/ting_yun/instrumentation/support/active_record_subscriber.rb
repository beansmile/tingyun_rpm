# encoding: utf-8

require 'ting_yun/instrumentation/support/evented_subscriber'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/instrumentation/support/active_record_helper'
require 'ting_yun/support/helper'
require 'ting_yun/agent/collector/transaction_sampler'
require 'ting_yun/agent/collector/sql_sampler'
require 'ting_yun/agent/database'

module TingYun
  module Instrumentation
    module Rails
      class ActiveRecordSubscriber < TingYun::Instrumentation::Support::EventedSubscriber
        CACHED_QUERY_NAME = 'CACHE'.freeze unless defined? CACHED_QUERY_NAME

        def initialize
          # We cache this in an instance variable to avoid re-calling method
          # on each query.
          @explainer = method(:explain_plan)
          super
        end

        def explain_plan(statement)
          TingYun::Agent::Database.explain_plan(statement)
        end

        def start(name, id, payload) #THREAD_LOCAL_ACCESS

          return if payload[:name] == CACHED_QUERY_NAME
          super
        rescue => e
          log_notification_error(e, name, 'start')
        end

        def finish(name, id, payload) #THREAD_LOCAL_ACCESS
          return if payload[:name] == CACHED_QUERY_NAME
          state = TingYun::Agent::TransactionState.tl_get
          event = pop_event(id)
          config = active_record_config_for_event(event)
          base, metric = record_metrics(event, config)
          notice_sql(state, event, config, base, metric)
        rescue Exception => e
          log_notification_error(e, name, 'finish')
        end


        def notice_sql(state, event, config, base, metric)
          stack  = state.traced_method_stack
          state.timings.sql_duration = state.timings.sql_duration + event.duration
          # enter transaction trace node
          frame = stack.push_frame(state, :active_record, event.time.to_f)

          sql_sampler.notice_sql(event.payload[:sql], base, config,
                                 TingYun::Helper.milliseconds_to_seconds(event.duration),
                                 state, @explainer, event.payload[:binds], event.payload[:name])

          transaction_sampler.notice_sql(event.payload[:sql], config, event.duration,
                                         state, @explainer, event.payload[:binds], event.payload[:name])
          # exit transaction trace node
          stack.pop_frame(state, frame, base, event.end.to_f, true, metric)
        end

        def record_metrics(event, config)
          metric, base, *other_metrics = TingYun::Instrumentation::Support::ActiveRecordHelper.metrics_for(event.payload[:name],
                                                                                                   TingYun::Helper.correctly_encoded(event.payload[:sql]),
                                                                                                   config)

          TingYun::Agent.agent.stats_engine.tl_record_scoped_and_unscoped_metrics(base, other_metrics, event.duration)

          return base, metric
        end


        def active_record_config_for_event(event)
          return unless event.payload[:connection_id]

          connection = nil
          connection_id = event.payload[:connection_id]

          ::ActiveRecord::Base.connection_handler.connection_pool_list.each do |handler|
            connection = handler.connections.detect do |conn|
              conn.object_id == connection_id
            end

            break if connection
          end

          connection.instance_variable_get(:@config) if connection
        end

        def transaction_sampler
          ::TingYun::Agent::Collector::TransactionSampler
        end

        def sql_sampler
          ::TingYun::Agent::Collector::SqlSampler
        end
      end
    end
  end
end