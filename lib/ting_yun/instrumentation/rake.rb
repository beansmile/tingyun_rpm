# encoding: utf-8

TingYun::Support::LibraryDetection.defer do

  named :rake

  depends_on do
    defined?(::Rake)&&
        !::TingYun::Agent.config[:'disable_rake'] &&
        ::TingYun::Agent.config[:'rake.tasks'].any? &&
        ::TingYun::Agent::Instrumentation::RakeInstrumentation.supported_version?
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing deferred Rake instrumentation'
    require 'ting_yun/agent/method_tracer_helpers'
  end

  executes do
    module Rake
      class Task
        alias_method :invoke_without_tingyun, :invoke
        def invoke(*args)
          unless TingYun::Agent::Instrumentation::RakeInstrumentation.should_trace? name
            return invoke_without_tingyun(*args)
          end

          TingYun::Agent::Instrumentation::RakeInstrumentation.before_invoke_transaction(self)

          state = TingYun::Agent::TransactionState.tl_get
          TingYun::Agent::Transaction.wrap(state, "BackgroundAction/Rake/invoke/#{name}", :rake)  do
            invoke_without_tingyun(*args)
          end
        end
      end
    end
  end
end

module TingYun
  module Agent
    module Instrumentation
      module RakeInstrumentation

        def self.supported_version?
          ::TingYun::Support::VersionNumber.new(::Rake::VERSION) >= ::TingYun::Support::VersionNumber.new("10.0.0")
        end

        def self.before_invoke_transaction(task)
          ensure_at_exit

          if task.application.options.always_multitask
            instrument_invoke_prerequisites_concurrently(task)
          else
            instrument_execute_on_prereqs(task)
          end
        rescue => e
          TingYun::Agent.logger.error("Error during Rake task invoke", e)
        end

        def self.should_trace? name
          TingYun::Agent.config[:'rake.tasks'].any? do |task|
            task == name
          end
        end

        def self.ensure_at_exit
          return if @installed_at_exit

          at_exit do
            # The agent's default at_exit might not default to installing, but
            # if we are running an instrumented rake task, we always want it.
            TingYun::Agent.shutdown
          end

          @installed_at_exit = true
        end

        def self.instrument_execute_on_prereqs(task)
          task.prerequisite_tasks.each do |child_task|
            instrument_execute(child_task)
          end
        end

        def self.instrument_execute(task)
          return if task.instance_variable_get(:@__tingyun_instrumented_execute)

          task.instance_variable_set(:@__tingyun_instrumented_execute, true)
          task.instance_eval do
            def execute(*args, &block)
              TingYun::Agent::MethodTracerHelpers.trace_execution_scoped("Rake/execute/#{self.name}") do
                super
              end
            end
          end

          instrument_execute_on_prereqs(task)
        end

        def self.instrument_invoke_prerequisites_concurrently(task)
          task.instance_eval do
            def invoke_prerequisites_concurrently(*_)
              TingYun::Agent::MethodTracerHelpers.trace_execution_scoped("Rake/execute/multitask") do
                super
              end
            end
          end
        end
      end
    end
  end
 end