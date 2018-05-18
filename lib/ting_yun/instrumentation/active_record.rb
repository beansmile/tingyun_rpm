# encoding: utf-8
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/instrumentation/support/active_record_helper'
require 'ting_yun/support/helper'
require 'ting_yun/agent/method_tracer_helpers'
require 'ting_yun/agent/collector/transaction_sampler'
require 'ting_yun/agent/collector/sql_sampler'
require 'ting_yun/agent/database'
require 'ting_yun/instrumentation/support/sinatra_helper'

module TingYun
  module Instrumentation
    module ActiveRecord



      def self.explain_plan(statement)
        TingYun::Agent::Database.explain_plan(statement)
      end

      EXPLAINER = method(:explain_plan)

      def self.included(instrumented_class)
        instrumented_class.class_eval do
          unless instrumented_class.method_defined?(:log_without_tingyun_instrumentation)
            alias_method :log_without_tingyun_instrumentation, :log
            alias_method :log, :log_with_tingyun_instrumentation
            protected :log
          end
        end
      end

      def self.instrument
        if defined?(::ActiveRecord::VERSION::MAJOR) && ::ActiveRecord::VERSION::MAJOR.to_i >= 3
          ::TingYun::Instrumentation::Support::ActiveRecordHelper.instrument_additional_methods
        end

        ::ActiveRecord::ConnectionAdapters::AbstractAdapter.module_eval do
          include ::TingYun::Instrumentation::ActiveRecord
        end
      end

      def log_with_tingyun_instrumentation(*args, &block)

        state = TingYun::Agent::TransactionState.tl_get
        sql, name, _ = args
        klass_name, *metrics = ::TingYun::Instrumentation::Support::ActiveRecordHelper.metrics_for(
            TingYun::Helper.correctly_encoded(name),
            TingYun::Helper.correctly_encoded(sql),
            @config)

        scoped_metric = metrics.first

        TingYun::Agent::MethodTracerHelpers.trace_execution_scoped(metrics, {}, nil, klass_name) do
          t0 = Time.now
          begin
            log_without_tingyun_instrumentation(*args, &block)
          ensure
            elapsed_time = (Time.now - t0).to_f
            state.timings.sql_duration = state.timings.sql_duration  + elapsed_time * 1000

            ::TingYun::Agent::Collector::TransactionSampler.notice_sql(sql, @config, elapsed_time, state, EXPLAINER)
            ::TingYun::Agent::Collector::SqlSampler.notice_sql(sql, scoped_metric, @config, elapsed_time, state, EXPLAINER)
          end

        end
      end
    end
  end
end


TingYun::Support::LibraryDetection.defer do
  named :active_record

  depends_on do
    !::TingYun::Agent.config[:disable_active_record]
  end

  depends_on do
    defined?(::ActiveRecord) && defined?(::ActiveRecord::Base) &&
        (!defined?(::ActiveRecord::VERSION) ||
            ::ActiveRecord::VERSION::MAJOR.to_i <= 3)
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing ActiveRecord instrumentation'
  end

  executes do
    require 'ting_yun/instrumentation/support/active_record_helper'

    if defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i == 3
      ActiveSupport.on_load(:active_record) do
        ::TingYun::Instrumentation::ActiveRecord.instrument
      end
    else
      ::TingYun::Instrumentation::ActiveRecord.instrument
    end
  end

end
