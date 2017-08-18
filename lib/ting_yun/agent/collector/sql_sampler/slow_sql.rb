# encoding: utf-8
require 'ting_yun/agent/database'
module TingYun
  module Agent
    module Collector
      class SlowSql
        attr_reader :statement
        attr_reader :metric_name
        attr_reader :duration
        attr_reader :backtrace
        attr_reader :start_time


        def initialize(statement, metric_name, duration, time,  backtrace=nil)
          @start_time = time
          @statement = statement
          @metric_name = metric_name
          @duration = duration
          @backtrace = backtrace
        end

        def sql
          statement.sql
        end

        def obfuscate
          TingYun::Agent::Database.obfuscate_sql(statement)
        end


        def normalize
          TingYun::Agent::Database::Obfuscator.instance.default_sql_obfuscator(statement)
        end

        def explain
          TingYun::Agent::Database.explain_sql(statement) if statement.config && statement.explainer
        end

        # We can't serialize the explainer, so clear it before we transmit
        def prepare_to_send
          statement.explainer = nil
        end
      end

    end
  end
end
