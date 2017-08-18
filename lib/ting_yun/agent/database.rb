# encoding: utf-8

require 'ting_yun/support/helper'
require 'ting_yun/agent/database/connection_manager'
require 'ting_yun/agent/database/statement'
require 'ting_yun/agent/database/obfuscator'

module TingYun
  module Agent
    # sql explain plan
    module Database

      MAX_QUERY_LENGTH = 16384

      extend self


      def explain_sql(statement)
        return nil unless statement.sql && statement.explainer && statement.config
        statement.sql = statement.sql.split(";\n")[0] # only explain the first
        return statement.explain || {"dialect"=> nil, "keys"=>[], "values"=>[]}
      end

      def explain_plan(statement)
        connection = get_connection(statement.config) do
          ::ActiveRecord::Base.send("#{statement.config[:adapter]}_connection",
                                    statement.config)
        end
        if connection
          if connection.respond_to?(:exec_query)
            return connection.exec_query("EXPLAIN #{statement.sql}",
                                         "Explain #{statement.name}",
                                         statement.binds)
          elsif connection.respond_to?(:execute)
            return connection.execute("EXPLAIN #{statement.sql}")
          end
        end
      end


      def obfuscate_sql(sql)
        TingYun::Agent::Database::Obfuscator.instance.obfuscator.call(sql)
      end


      def capture_query(query)
        TingYun::Helper.correctly_encoded(truncate_query(query))
      end

      def truncate_query(query)
        if query.length > (MAX_QUERY_LENGTH - 4)
          query[0..MAX_QUERY_LENGTH - 4] + '...'
        else
          query
        end
      end



      def record_sql_method(key)

        case Agent.config[key].to_s
          when 'off'
            :off
          when 'raw'
            :raw
          else
            :obfuscated
        end
      end


      def get_connection(config, &connector)
        TingYun::Agent::Database::ConnectionManager.instance.get_connection(config, &connector)
      end

      def close_connections
        TingYun::Agent::Database::ConnectionManager.instance.close_connections
      end



      RECORD_FOR = [:raw, :obfuscated].freeze

      def should_record_sql?(key)
        RECORD_FOR.include?(record_sql_method(key.to_sym))
      end

      def sql_sampler_enabled?
        Agent.config[:'nbs.action_tracer.enabled'] &&
            Agent.config[:'nbs.action_tracer.slow_sql'] &&
            should_record_sql?('nbs.action_tracer.record_sql')
      end

      def should_action_collect_explain_plans?
        should_record_sql?("nbs.action_tracer.record_sql") &&
            Agent.config["nbs.action_tracer.explain_enabled".to_sym]
      end

    end
  end
end
