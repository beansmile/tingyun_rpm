# encoding: utf-8
require 'ting_yun/agent/transaction/transaction_state'
module TingYun
  module Agent
    module Datastore
      module MetricHelper


        ALL_WEB = "AllWeb".freeze
        ALL_BACKGROUND = "AllBackground".freeze
        ALL = "All".freeze
        UNKNOWN = 'Unknown'.freeze
        NOSQL = %w(MongoDB Redis Memcached).freeze

        CACHE = %w(Redis Memcached).freeze

        def self.checkNosql(product)
          NOSQL.include?(product)
        end

        def self.metric_name(product, collection, operation,host,port,dbname)
          if checkNosql(product)
            return "#{product}/#{host}:#{port}%2F#{dbname}%2F#{collection}/#{operation}" if product=="MongoDB"
            "#{product}/#{host}:#{port}%2F#{collection}/#{operation}"
          else
            "Database #{product}/#{host}:#{port}%2F#{dbname}%2F#{collection}/#{operation}"
          end
        end

        def self.metric_name_others(product, collection, operation)
          collection ||= 'NULL'
          if checkNosql(product)
            "#{product}%2F#{collection}/#{operation}"
          else
            "Database #{product}%2F#{collection}/#{operation}"
          end
        end

        def self.product_suffixed_rollup(product,suffix)
          if checkNosql(product)
            "#{product}/NULL/#{suffix}"
          else
            "Database #{product}/NULL/#{suffix}"
          end
        end

        def self.metrics_for(product, operation, host = UNKNOWN, port = 0, dbname = UNKNOWN, collection = nil,  generic_product = nil )
          dbname ||= UNKNOWN
          host ||= UNKNOWN
          port ||= UNKNOWN
          operation = operation.to_s.upcase
          if overrides = overridden_operation_and_collection   # [method, model_name, product]
            if should_override?(overrides, product, generic_product)
              operation  = overrides[0] || operation
              collection = overrides[1] || collection
            end
          end
          metrics  = [operation]
          if TingYun::Agent::Transaction.recording_web_transaction?
            metrics = metrics + [ALL_WEB,ALL]
          else
            metrics = metrics + [ALL_BACKGROUND,ALL]
          end


          metrics = metrics.map do |suffix|
            product_suffixed_rollup(product,suffix)
          end

          if checkNosql(product)
            metrics << (product=="MongoDB" ? "#{product}/#{host}:#{port}%2F#{dbname}/All" : "#{product}/#{host}:#{port}/All")
          else
            metrics << "Database #{product}/#{host}:#{port}%2F#{dbname}/All"
          end
          metrics.unshift metric_name(product, collection, operation,host,port,dbname) if collection
          metrics.unshift  "#{product}/#{host}:#{port}/#{operation}" if product=="Memcached"
          metrics.unshift  metric_name_others(product, collection, operation)
          metrics
        end

        def self.include_database?(name)
          CACHE.include?(name)
        end
        # Allow Transaction#with_database_metric_name to override our
        # collection and operation
        def self.overridden_operation_and_collection #THREAD_LOCAL_ACCESS
          state = TingYun::Agent::TransactionState.tl_get
          txn   = state.current_transaction
          txn ? txn.instrumentation_state[:datastore_override] : nil
        end

        # If the override declared a product affiliation, abide by that
        # ActiveRecord has database-specific product names, so we recognize
        # it by the generic_product it passes.
        def self.should_override?(overrides, product, generic_product)
          override_product = overrides[2]

          override_product.nil? ||
              override_product == product ||
              override_product == generic_product
        end

      end
    end
  end
end

