# encoding: utf-8
require 'ting_yun/agent/database/obfuscator'

module TingYun
  module Agent
    module Database
      module ExplainPlanHelpers

        def handle_exception_in_explain
          yield
        rescue => e
          begin
            # guarantees no throw from explain_sql
            ::TingYun::Agent.logger.error("Error getting query plan:", e)
            nil
          rescue
            # double exception. throw up your hands
            nil
          end
        end

        def is_select?(sql)
          parse_operation_from_query(sql) == 'select'
        end

        def parameterized?(sql)
          TingYun::Agent::Database::Obfuscator.instance.obfuscate_single_quote_literals(sql) =~ /\$\d+/
        end

        SQL_COMMENT_REGEX = Regexp.new('/\*.*?\*/', Regexp::MULTILINE).freeze
        EMPTY_STRING      = ''.freeze


        KNOWN_OPERATIONS = [
            'alter',
            'select',
            'update',
            'delete',
            'insert',
            'create',
            'show',
            'set',
            'exec',
            'execute',
            'call'
        ]

        def parse_operation_from_query(sql)
          sql = TingYun::Helper.correctly_encoded(sql).gsub(SQL_COMMENT_REGEX, EMPTY_STRING)
          if sql =~ /(\w+)/
            op = $1.downcase
            return op if KNOWN_OPERATIONS.include?(op)
          end
        end




        POSTGRES_PREFIX = 'postgres'.freeze
        MYSQL_PREFIX    = 'mysql'.freeze
        MYSQL2_PREFIX   = 'mysql2'.freeze
        SQLITE_PREFIX   = 'sqlite'.freeze

        def symbolized_adapter(adapter)
          if adapter.start_with? POSTGRES_PREFIX
            :postgres
          elsif adapter == MYSQL_PREFIX
            :mysql
            # For the purpose of fetching explain plans, we need to maintain the distinction
            # between usage of mysql and mysql2. Obfuscation is the same, though.
          elsif adapter == MYSQL2_PREFIX
            :mysql2
          elsif adapter.start_with? SQLITE_PREFIX
            :sqlite
          else
            adapter.to_sym
          end
        end


        def process_resultset(results, adapter)
          if adapter == :postgres
            return process_explain_results_postgres(results)
          elsif defined?(::ActiveRecord::Result) && results.is_a?(::ActiveRecord::Result)
            # Note if adapter is mysql, will only have headers, not values
            return [results.columns, results.rows]
          elsif results.is_a?(String)
            return string_explain_plan_results(results)
          end

          case adapter
            when :mysql2
              process_explain_results_mysql2(results)
            when :mysql
              process_explain_results_mysql(results)
            when :sqlite
              process_explain_results_sqlite(results)
            else
              return {}
          end
        end

        QUERY_PLAN = 'QUERY PLAN'.freeze

        def process_explain_results_postgres(results)
          if defined?(::ActiveRecord::Result) && results.is_a?(::ActiveRecord::Result)
            query_plan_string = results.rows.join("\n")
          elsif results.is_a?(String)
            query_plan_string = results
          else
            lines = []
            results.each { |row| lines << row[QUERY_PLAN] }
            query_plan_string = lines.join("\n")
          end

          unless TingYun::Agent::Database.record_sql_method("nbs.action_tracer.record_sql") == :raw
            query_plan_string = TingYun::Agent::Database::Obfuscator.instance.obfuscate_postgres_explain(query_plan_string)
          end
          values = query_plan_string.split("\n").map { |line| [line] }

          {"dialect"=> "PostgreSQL", "keys"=>[QUERY_PLAN], "values"=>values}
        end


        def string_explain_plan_results(adpater, results)
          {"dialect"=> adpater, "keys"=>[], "values"=>[results]}
        end

        def process_explain_results_mysql2(results)
          headers = results.fields
          values  = []
          results.each { |row| values << row }
          {"dialect"=> "MySQL", "keys"=>headers, "values"=>values}
        end

        def process_explain_results_mysql(results)
          headers = []
          values  = []
          if results.is_a?(Array)
            # We're probably using the jdbc-mysql gem for JRuby, which will give
            # us an array of hashes.
            headers = results.first.keys
            results.each do |row|
              values << headers.map { |h| row[h] }
            end
          else
            # We're probably using the native mysql driver gem, which will give us
            # a Mysql::Result object that responds to each_hash
            results.each_hash do |row|
              headers = row.keys
              values << headers.map { |h| row[h] }
            end
          end
          {"dialect"=> "MySQL", "keys"=>headers, "values"=>values}
        end

        SQLITE_EXPLAIN_COLUMNS = %w[addr opcode p1 p2 p3 p4 p5 comment]

        def process_explain_results_sqlite(results)
          headers = SQLITE_EXPLAIN_COLUMNS
          values  = []
          results.each do |row|
            values << headers.map { |h| row[h] }
          end
          {"dialect"=> "sqlite", "keys"=>headers, "values"=>values}
        end



      end
    end
  end
end