# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/instrumentation/support/metric_translator'

module TingYun
  module Instrumentation
    module Mongo
      extend self

      def install_mongo_instrumentation
        hook_instrument_methods
        instrument
      end

      def hook_instrument_methods
        hook_instrument_method(::Mongo::Collection)
        hook_instrument_method(::Mongo::Connection)
        hook_instrument_method(::Mongo::Cursor)
        hook_instrument_method(::Mongo::CollectionWriter) if defined?(::Mongo::CollectionWriter)
      end


      def hook_instrument_method(target_class)
        target_class.class_eval do
          require 'ting_yun/agent/method_tracer_helpers'

          def record_mongo_duration(duration)
            state = TingYun::Agent::TransactionState.tl_get
            if state
              state.timings.mon_duration = state.timings.mon_duration +  duration * 1000
            end
          end

          def tingyun_host_port
           return @db.connection.host_port if self.instance_variable_defined? :@db
           return @host_to_try if self.instance_variable_defined? :@host_to_try
           return ['Unknown', 'Unknown']
          end

          def tingyun_generate_metrics(operation, payload = nil)
            payload ||= { :collection => self.name, :database => self.db.name }
            TingYun::Instrumentation::Support::MetricTranslator.metrics_for(operation, payload, tingyun_host_port)
          end

          def instrument_with_tingyun(name, payload = {}, &block)
            klass_name, *metrics = tingyun_generate_metrics(name, payload)

            TingYun::Agent::MethodTracerHelpers.trace_execution_scoped(metrics, payload, method(:record_mongo_duration), klass_name) do
              instrument_without_tingyun(name, payload, &block)
            end
          end

          alias_method :instrument_without_tingyun, :instrument
          alias_method :instrument, :instrument_with_tingyun
        end
      end

      def instrument
        ::Mongo::Collection.class_eval do
          def save_with_tingyun(doc, opts = {}, &block)
            klass_name, *metrics = tingyun_generate_metrics(:save)
            TingYun::Agent::MethodTracerHelpers.trace_execution_scoped(metrics, opts, method(:record_mongo_duration), klass_name) do
              save_without_tingyun(doc, opts, &block)
            end
          end

          alias_method :save_without_tingyun, :save
          alias_method :save, :save_with_tingyun

          def ensure_index_with_tingyun(spec, opts = {}, &block)
            klass_name, *metrics = tingyun_generate_metrics(:ensureIndex)
            TingYun::Agent::MethodTracerHelpers.trace_execution_scoped(metrics, opts, method(:record_mongo_duration), klass_name) do
              ensure_index_without_tingyun(spec, opts, &block)
            end
          end

          alias_method :ensure_index_without_tingyun, :ensure_index
          alias_method :ensure_index, :ensure_index_with_tingyun
        end
      end

    end
  end
end

TingYun::Support::LibraryDetection.defer do
  named :mongo

  depends_on do
    !::TingYun::Agent.config[:disable_mongo]
  end

  depends_on do
    defined?(::Mongo)
  end

  depends_on do
    TingYun::Agent::Datastore::Mongo.supported_version? && !TingYun::Agent::Datastore::Mongo.unsupported_2x?
  end

  executes do
    TingYun::Agent.logger.info 'Installing Mongo instrumentation'
  end

  executes do
    TingYun::Instrumentation::Mongo.install_mongo_instrumentation
  end
end
