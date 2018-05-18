# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/agent/datastore/metric_helper'
require 'ting_yun/agent/datastore/mongo'
require 'ting_yun/instrumentation/support/event_formatter'
require 'ting_yun/agent/collector/transaction_sampler'

module TingYun
  module Instrumentation
    class MongoCommandLogSubscriber

      MONGODB = 'MongoDB'.freeze
      GET_MORE = "getMore".freeze
      COLLECTION = "collection".freeze

      def started(event)
        begin
          operations[event.operation_id] = event
        rescue Exception => e
          log_notification_error('started', e)
        end
      end


      def completed(event)
        begin
          state = TingYun::Agent::TransactionState.tl_get
          state.timings.mon_duration = state.timings.mon_duration +  event.duration * 1000
          started_event = operations.delete(event.operation_id)

          klass_name, base, *other_metrics = metrics(started_event)

          TingYun::Agent.instance.stats_engine.tl_record_scoped_and_unscoped_metrics(
              base, other_metrics, event.duration*1000
          )
          notice_nosql_statement(state, started_event, base, event.duration, klass_name)
        rescue Exception => e
          log_notification_error('completed', e)
        end
      end

      alias :succeeded :completed
      alias :failed :completed




      private

      def collection(event)
        if event.command_name == GET_MORE
          event.command[COLLECTION]
        else
          event.command.values.first
        end
      end

      def log_notification_error(event_type, error)
        TingYun::Agent.logger.error("Error during MongoDB #{event_type} event:")
        TingYun::Agent.logger.log_exception(:error, error)
        TingYun::Agent.notice_error(error,:type=>:exception)
      end


      def operations
        @operations ||= {}
      end

      def metrics(event)
        TingYun::Agent::Datastore::MetricHelper.metrics_for(MONGODB, TingYun::Agent::Datastore::Mongo.transform_operation(event.command_name), event.address.host, event.address.port, event.database_name, collection(event))
      end

      def generate_statement(event)
        TingYun::Instrumentation::Support::EventFormatter.format(
            event.command_name,
            event.database_name,
            event.command
        )
      end

      def notice_nosql_statement(state, event, metric, duration, klass_name)
        end_time = Time.now.to_f

        stack  = state.traced_method_stack

        # enter transaction trace node
        frame = stack.push_frame(state, :mongo_db, end_time - duration)

        transaction_sampler.notice_nosql_statement(generate_statement(event),duration*1000)

        # exit transaction trace node
        stack.pop_frame(state, frame, metric, end_time, true, klass_name)
      end

      def transaction_sampler
        ::TingYun::Agent::Collector::TransactionSampler
      end
    end
  end
end
