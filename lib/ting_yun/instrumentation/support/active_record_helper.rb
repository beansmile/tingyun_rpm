# encoding: utf-8


require 'ting_yun/instrumentation/support/database'
require 'ting_yun/agent/datastore/metric_helper'
require 'ting_yun/agent'
module TingYun
  module Instrumentation
    module Support
      module ActiveRecordHelper
        module_function


        ACTIVE_RECORD = "ActiveRecord".freeze unless defined?(ACTIVE_RECORD)
        DATA_MAPPER = "DataMapper".freeze

        # Used by both the AR 3.x and 4.x instrumentation
        def instrument_additional_methods
          instrument_save_methods
          instrument_relation_methods
        end

        def instrument_save_methods
          ::ActiveRecord::Base.class_eval do
            alias_method :save_without_tingyun, :save

            def save(*args, &blk)
              ::TingYun::Agent.with_database_metric_name(self.class.name, nil, ACTIVE_RECORD) do
                save_without_tingyun(*args, &blk)
              end
            end

            alias_method :save_without_tingyun!, :save!

            def save!(*args, &blk)
              ::TingYun::Agent.with_database_metric_name(self.class.name, nil, ACTIVE_RECORD) do
                save_without_tingyun!(*args, &blk)
              end
            end
          end
        end

        def instrument_relation_methods

          ::ActiveRecord::Relation.class_eval do
            alias_method :update_all_without_tingyun, :update_all

            def update_all(*args, &blk)
              ::TingYun::Agent.with_database_metric_name(self.name, nil, ACTIVE_RECORD) do
                update_all_without_tingyun(*args, &blk)
              end
            end

            alias_method :delete_all_without_tingyun, :delete_all

            def delete_all(*args, &blk)
              ::TingYun::Agent.with_database_metric_name(self.name, nil, ACTIVE_RECORD) do
                delete_all_without_tingyun(*args, &blk)
              end
            end

            alias_method :destroy_all_without_tingyun, :destroy_all

            def destroy_all(*args, &blk)
              ::TingYun::Agent.with_database_metric_name(self.name, nil, ACTIVE_RECORD) do
                destroy_all_without_tingyun(*args, &blk)
              end
            end
          end
        end

        def metrics_for(name, sql, config)
          config ||={}
          product = map_product(config[:adapter])
          splits = split_name(name)
          model = model_from_splits(splits) || product
          operation = operation_from_splits(splits, sql)

          TingYun::Agent::Datastore::MetricHelper.metrics_for(product, operation, config[:host], config[:port], config[:database], model, ACTIVE_RECORD)
        end

        def metrics_for_data_mapper(name, sql, config, model=nil)
          if config
            product = map_product(config.query['adapter'])
            operation = name || TingYun::Instrumentation::Support::Database.parse_operation_from_query(sql)
            model ||= product
            db = config.query['database'] || config.path.split('/').last
            host = config.host
            port = config.port
            host = nil if config.host && config.host.empty?
            port = nil if config.host && config.host.empty?
            TingYun::Agent::Datastore::MetricHelper.metrics_for(product, operation, host, port, db, model, DATA_MAPPER)
          end
        end

        SPACE = ' '.freeze unless defined?(SPACE)
        EMPTY = [].freeze unless defined?(EMPTY)

        def split_name(name)
          if name && name.respond_to?(:split)
            name.split(SPACE)
          else
            EMPTY
          end
        end

        def model_from_splits(splits)
          if splits.length == 2
            splits.first
          else
            nil
          end
        end

        def operation_from_splits(splits, sql)
          if splits.length == 2
            map_operation(splits[1])
          else
            TingYun::Instrumentation::Support::Database.parse_operation_from_query(sql)
          end
        end

        # These are used primarily to optimize and avoid allocation on well
        # known operations coming in. Anything not matching the list is fine,
        # it just needs to get downcased directly for use.
        OPERATION_NAMES = {
            'Find' => 'SELECT',
            'Load' => 'SELECT',
            'Count' => 'SELECT',
            'Exists' => 'SELECT',
            'Create' => 'INSERT',
            'Columns' => 'SELECT',
            'Indexes' => 'SELECT',
            'Destroy' => 'DELETE',
            'Update' => 'UPDATE',
            'Save' => 'INSERT'
        }.freeze unless defined?(OPERATION_NAMES)

        def map_operation(raw_operation)
          direct_op = OPERATION_NAMES[raw_operation]
          return direct_op if direct_op

          # raw_operation.upcase
        end

        PRODUCT_NAMES = {
            "mysql" => "MySQL",
            "mysql2" => "MySQL",

            "postgresql" => "PostgreSQL",

            "postgres" => 'PostgreSQL',

            "sqlite3" => "SQLite",

            # https://rubygems.org/gems/activerecord-jdbcpostgresql-adapter
            "jdbcmysql" => "MySQL",

            # https://rubygems.org/gems/activerecord-jdbcpostgresql-adapter
            "jdbcpostgresql" => "PostgreSQL",

            # https://rubygems.org/gems/activerecord-jdbcsqlite3-adapter
            "jdbcsqlite3" => "SQLite",

            # https://rubygems.org/gems/activerecord-jdbcderby-adapter
            "derby" => "Derby",
            "jdbcderby" => "Derby",

            # https://rubygems.org/gems/activerecord-jdbc-adapter
            "jdbc" => "JDBC",

            # https://rubygems.org/gems/activerecord-jdbcmssql-adapter
            "jdbcmssql" => "MSSQL",
            "mssql" => "MSSQL",

            # https://rubygems.org/gems/activerecord-sqlserver-adapter
            "sqlserver" => "SQLServer",

            # https://rubygems.org/gems/activerecord-odbc-adapter
            "odbc" => "ODBC",

            # https://rubygems.org/gems/activerecord-oracle_enhanced-adapter
            "oracle_enhanced" => "Oracle"
        }.freeze unless defined?(PRODUCT_NAMES)

        DEFAULT_PRODUCT_NAME = "Database".freeze unless defined?(DEFAULT_PRODUCT_NAME)

        def map_product(adapter_name)
          PRODUCT_NAMES.fetch(adapter_name, DEFAULT_PRODUCT_NAME)
        end
      end
    end
  end
end

