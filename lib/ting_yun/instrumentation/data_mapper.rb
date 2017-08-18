# encoding: utf-8
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/instrumentation/support/active_record_helper'
require 'ting_yun/agent/method_tracer_helpers'

module TingYun::Instrumentation::DataMapper

  MIN_SUPPORT_VERSION = '1.1.0.rc1'.freeze

  def self.supported_version?
    ::TingYun::Support::VersionNumber.new(::DataMapper::VERSION) >= ::TingYun::Support::VersionNumber.new(MIN_SUPPORT_VERSION)
  end

  def self.support_data_mapper?
    defined?(::DataMapper) &&
        ((defined?(::DataMapper::Adapters) && defined?(::DataMapper::Adapters::DataObjectsAdapter)) ||
         (defined?(::DataMapper::Aggregates) && defined?(::DataMapper::Aggregates::DataObjectsAdapter))) &&
        supported_version?
  end

end

TingYun::Support::LibraryDetection.defer do
  named :data_mapper

  depends_on do
    !::TingYun::Agent.config[:disable_data_mapper]
  end

  depends_on do
    begin
      require 'dm-do-adapter'
      TingYun::Instrumentation::DataMapper.support_data_mapper?
    rescue LoadError
      false
    end
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing DataMapper instrumentation'
  end

  executes do

    if defined?(::DataMapper::Adapters) && defined?(::DataMapper::Adapters::DataObjectsAdapter)
      ::DataMapper::Adapters::DataObjectsAdapter.class_eval do

        def create(resources)
          name = self.name

          resources.each do |resource|
            model      = resource.model
            state = TingYun::Agent::TransactionState.tl_get
            *params = get_metrics_params(:create, model)
            klass_name, *metrics = ::TingYun::Instrumentation::Support::ActiveRecordHelper.metrics_for_data_mapper(*params)

            TingYun::Agent::MethodTracerHelpers.trace_execution_scoped(metrics, {}, nil, klass_name) do
              t0 = Time.now
              begin
                serial     = model.serial(name)
                attributes = resource.dirty_attributes

                properties  = []
                bind_values = []

                # make the order of the properties consistent
                model.properties(name).each do |property|
                  next unless attributes.key?(property)

                  bind_value = attributes[property]

                  # skip insering NULL for columns that are serial or without a default
                  next if bind_value.nil? && (property.serial? || !property.default?)

                  # if serial is being set explicitly, do not set it again
                  if property.equal?(serial)
                    serial = nil
                  end

                  properties  << property
                  bind_values << bind_value
                end

                statement = insert_statement(model, properties, serial)

                result = with_connection do |connection|
                  connection.create_command(statement).execute_non_query(*bind_values)
                end

                if result.affected_rows == 1 && serial
                  serial.set!(resource, result.insert_id)
                end
              ensure
                elapsed_time = (Time.now - t0).to_f
                state.timings.sql_duration = state.timings.sql_duration  + elapsed_time * 1000
              end
            end
          end
        end

        [:read, :update, :delete, :select, :execute].each do |method|
          next unless public_method_defined? method
          alias_method "#{method}_without_tingyun_trace".to_sym, method.to_sym

          define_method method do |*args, &block|
            state = TingYun::Agent::TransactionState.tl_get
            *params = get_metrics_params(method, *args, &block)
            klass_name, *metrics = ::TingYun::Instrumentation::Support::ActiveRecordHelper.metrics_for_data_mapper(*params)

            TingYun::Agent::MethodTracerHelpers.trace_execution_scoped(metrics, {}, nil, klass_name) do
              t0 = Time.now
              begin
                send "#{method}_without_tingyun_trace", *args, &block
              ensure
                elapsed_time = (Time.now - t0).to_f
                state.timings.sql_duration = state.timings.sql_duration  + elapsed_time * 1000
              end
            end
          end
        end

        def get_metrics_params(method, *args, &block)
          case method
            when :read
              query = args[0]
              return TingYun::Helper.correctly_encoded('SELECT'), nil, self.normalized_uri, DataMapper::Inflector.classify(query.model.storage_name(name))
            when :update
              collection = args[1]
              return TingYun::Helper.correctly_encoded('UPDATE'), nil, self.normalized_uri, DataMapper::Inflector.classify(collection.query.model.storage_name(name))
            when :delete
              collection = args[0]
              return TingYun::Helper.correctly_encoded('DELETE'), nil, self.normalized_uri, DataMapper::Inflector.classify(collection.query.model.storage_name(name))
            when :create
              model = args[0]
              return TingYun::Helper.correctly_encoded('INSERT'), nil, self.normalized_uri, DataMapper::Inflector.classify(model.storage_name(name))
            when :select, :execute
              sql = args[0]
              return nil, sql, self.normalized_uri
          end
        end
      end
    end

    if defined?(::DataMapper::Aggregates) && defined?(::DataMapper::Aggregates::DataObjectsAdapter)
      ::DataMapper::Aggregates::DataObjectsAdapter.class_eval do

        alias_method :aggregate_without_tingyun_trace, :aggregate

        def aggregate(*args, &block)
          state = TingYun::Agent::TransactionState.tl_get
          *params = get_metrics_params(:read, *args, &block)
          klass_name, *metrics = ::TingYun::Instrumentation::Support::ActiveRecordHelper.metrics_for_data_mapper(*params)

          TingYun::Agent::MethodTracerHelpers.trace_execution_scoped(metrics, {}, nil, klass_name) do
            t0 = Time.now
            begin
              aggregate_without_tingyun_trace(*args, &block)
            ensure
              elapsed_time = (Time.now - t0).to_f
              state.timings.sql_duration = state.timings.sql_duration  + elapsed_time * 1000
            end
          end
        end
      end
    end
  end
end
