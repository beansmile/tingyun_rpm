# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/agent/collector/error_collector/noticed_error'
require 'ting_yun/agent/collector/error_collector/error_trace_array'

module TingYun
  module Agent
    module Collector
      class ErrorCollector
        ERRORS_ACTION = "Errors/Count/".freeze



        ERRORS_ALL = "Errors/Count/All".freeze
        ERRORS_ALL_WEB = "Errors/Count/AllWeb".freeze
        ERRORS_ALL_BACK_GROUND = "Errors/Count/AllBackground".freeze

        # Maximum possible length of the queue - defaults to 20, may be
        MAX_ERROR_QUEUE_LENGTH = 20 unless defined? MAX_ERROR_QUEUE_LENGTH

        #tag the exception,avoid the same exception record  multiple times in the middlwars and other point
        module Tag

          EXCEPTION_TAG_IVAR = :'@__ty_seen_exception' unless defined? EXCEPTION_TAG_IVAR

          def tag_exception(exception)
            begin
              exception.instance_variable_set(EXCEPTION_TAG_IVAR, true)
            rescue => e
              TingYun::Agent.logger.warn("Failed to tag exception: #{exception}: ", e)
            end
          end

          def exception_tagged?(exception)
            exception.instance_variable_defined?(EXCEPTION_TAG_IVAR)
          end

        end
        include Tag

        module Metric
          def aggregated_metric_names(txn)
            metric_names = [ERRORS_ALL]
            return metric_names unless txn

            if TingYun::Agent::Transaction.recording_web_transaction?
              metric_names << ERRORS_ALL_WEB
            else
              metric_names << ERRORS_ALL_BACK_GROUND
            end

            metric_names
          end

          def action_metric_name(txn)
            "#{ERRORS_ACTION}#{txn.best_name}" if txn
          end

        end
        include Metric

        attr_reader :error_trace_array, :external_error_array

        def initialize
          @error_trace_array = ::TingYun::Agent::Collector::ErrorTraceArray.new(MAX_ERROR_QUEUE_LENGTH)
          @external_error_array = ::TingYun::Agent::Collector::ErrorTraceArray.new(MAX_ERROR_QUEUE_LENGTH)
        end

        # See TingYun::Agent.notice_error for options and commentary
        def notice_error(exception, options={})
          tag_exception(exception)
          state = ::TingYun::Agent::TransactionState.tl_get
          increment_error_count(state)
          noticed_error = create_noticed_error(exception, options)
          if noticed_error.is_external_error
            external_error_array.add_to_error_queue(noticed_error)
          else
            error_trace_array.add_to_error_queue(noticed_error)
          end
        rescue => e
          ::TingYun::Agent.logger.warn("Failure when capturing error '#{exception}':", e)
          nil
        end

        # Increments a statistic that tracks total error rate
        def increment_error_count(state)
          txn = state.current_transaction

          metric_names = aggregated_metric_names(txn)

          action_metric = action_metric_name(txn)
          metric_names << action_metric if action_metric

          stats_engine = TingYun::Agent.agent.stats_engine
          stats_engine.record_unscoped_metrics(state, metric_names) do |stats|
            stats.increment_count
          end
        end

        EMPTY_STRING = ''.freeze

        def create_noticed_error(exception, options)
          attributes = options[:attributes]
          error_metric = attributes.agent_attributes[:metric_name] || EMPTY_STRING
          noticed_error = TingYun::Agent::Collector::NoticedError.new(error_metric, exception)
          noticed_error.attributes  = attributes
          noticed_error.stack_trace = extract_stack_trace(exception)
          noticed_error
        end


        def skip_notice_error?(exception)
          exception_tagged?(exception)
        end

        # calls a method on an object, if it responds to it - used for
        # detection and soft fail-safe. Returns nil if the method does
        # not exist
        def sense_method(object, method)
          object.send(method) if object.respond_to?(method)
        end

        # extracts a stack trace from the exception for debugging purposes
        def extract_stack_trace(exception)
          actual_exception = sense_method(exception, 'original_exception') || exception
          sense_method(actual_exception, 'backtrace') || '<no stack trace>'
        end

        # *Use sparingly for difficult to track bugs.*
        #
        # Track internal agent errors for communication back to TingYun
        # To use, make a specific subclass of  TingYun::Support::Exception::InternalAgentError,
        # then pass an instance of it to this method when your problem occurs.
        #
        # Limits are treated differently for these errors. We only gather one per
        # class per harvest, disregarding (and not impacting) the app error queue
        # limit.
        def notice_agent_error(exception)
          error_trace_array.notice_agent_error(exception)
        end

        def reset!
          @error_trace_array.reset!
          @external_error_array.reset!
          nil
        end
      end
    end
  end
end
