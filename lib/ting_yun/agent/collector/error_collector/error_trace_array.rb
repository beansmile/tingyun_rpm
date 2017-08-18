# encoding: utf-8

require 'ting_yun/agent'

module TingYun
  module Agent
    module Collector
      class ErrorTraceArray
        def initialize(capacity)
          @capacity = capacity
          @lock = Mutex.new
          @errors = []
        end

        def enabled?
          ::TingYun::Agent.config[:'nbs.error_collector.enabled']
        end

        def merge!(errors)
          errors.each do |error|
            add_to_error_queue(error)
          end
        end


        def reset!
          @lock.synchronize do
            @errors = []
          end
        end


        # Get the errors currently queued up.  Unsent errors are left
        # over from a previous unsuccessful attempt to send them to the server.
        def harvest!
          @lock.synchronize do
            errors = @errors
            @errors = []
            errors
          end
        end

        # Synchronizes adding an error to the error queue, and checks if
        # the error queue is too long - if so, we drop the error on the
        # floor after logging a warning.
        def add_to_error_queue(noticed_error)
          return unless enabled?
          @lock.synchronize do
            if !over_queue_limit?(noticed_error.message) && !@errors.include?(noticed_error)
              @errors << noticed_error
            end
          end
        end


        # checks the size of the error queue to make sure we are under
        # the maximum limit, and logs a warning if we are over the limit.
        def over_queue_limit?(message)
          over_limit = (@errors.reject { |err| err.is_internal }.length >= @capacity)
          if over_limit
            ::TingYun::Agent.logger.warn("The error reporting queue has reached #{@capacity}. The error detail for this and subsequent errors will not be transmitted to TingYun  until the queued errors have been sent: #{message}")
          end
          over_limit
        end

        # see TingYun::Agent::Instance.error_collector.notice_agent_error
        def notice_agent_error(exception)
          return unless exception.class < TingYun::Support::Exception::InternalAgentError

          TingYun::Agent.logger.info(exception)

          @lock.synchronize do
            return if @errors.any? { |err| err.exception_class_name == exception.class.name }

            trace = exception.backtrace || caller.dup
            noticed_error = TingYun::Agent::Collector::NoticedError.new("TingYun/AgentError", exception)
            noticed_error.stack_trace = trace
            @errors << noticed_error
          end
        rescue => e
          TingYun::Agent.logger.info("Unable to capture internal agent error due to an exception:", e)
        end

      end
    end
  end
end

