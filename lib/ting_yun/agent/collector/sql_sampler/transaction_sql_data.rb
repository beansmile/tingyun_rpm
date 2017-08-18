# encoding: utf-8

module TingYun
  module Agent
    module Collector
      class TransactionSqlData
        attr_reader :metric_name
        attr_reader :uri
        attr_reader :sql_data

        def initialize(uri)
          @sql_data = []
          @uri = uri
        end

        def set_transaction_info(uri)
          @uri = uri
        end

        def set_transaction_name(name)
          @metric_name = name
        end
      end
    end
  end
end
