# encoding: utf-8

module TingYun
  module Agent
    module Database

      #混淆器
      class Obfuscator
        include Singleton

        attr_reader :obfuscator

        def initialize
          reset
        end

        def reset
          @obfuscator = method(:default_sql_obfuscator)
        end

        QUERY_TOO_LARGE_MESSAGE     = "Query too large (over 16k characters) to safely obfuscate"
        FAILED_TO_OBFUSCATE_MESSAGE = "Failed to obfuscate SQL query - quote characters remained after obfuscation"

        def default_sql_obfuscator(sql)
          stmt = sql.kind_of?(Statement) ? sql : Statement.new(sql)

          if stmt.sql[-3,3] == '...'
            return QUERY_TOO_LARGE_MESSAGE
          end

          obfuscate(stmt.sql, stmt.adapter).to_s
        end






        module ObfuscationHelpers
          COMPONENTS_REGEX_MAP = {
              :single_quotes => /'(?:[^']|'')*?(?:\\'.*|'(?!'))/,
              :double_quotes => /"(?:[^"]|"")*?(?:\\".*|"(?!"))/,
              :dollar_quotes => /(\$(?!\d)[^$]*?\$).*?(?:\1|$)/,
              :uuids => /\{?(?:[0-9a-fA-F]\-*){32}\}?/,
              :numeric_literals => /\b-?(?:[0-9]+\.)?[0-9]+([eE][+-]?[0-9]+)?\b/,
              :boolean_literals => /\b(?:true|false|null)\b/i,
              :hexadecimal_literals => /0x[0-9a-fA-F]+/,
              :comments => /(?:#|--).*?(?=\r|\n|$)/i,
              :multi_line_comments => /\/\*(?:[^\/]|\/[^*])*?(?:\*\/|\/\*.*)/,
              :oracle_quoted_strings => /q'\[.*?(?:\]'|$)|q'\{.*?(?:\}'|$)|q'\<.*?(?:\>'|$)|q'\(.*?(?:\)'|$)/
          }

          DIALECT_COMPONENTS = {
              :fallback   => COMPONENTS_REGEX_MAP.keys,
              :mysql      => [:single_quotes, :double_quotes, :numeric_literals, :boolean_literals,
                              :hexadecimal_literals, :comments, :multi_line_comments],
              :postgres   => [:single_quotes, :dollar_quotes, :uuids, :numeric_literals,
                              :boolean_literals, :comments, :multi_line_comments],
              :sqlite     => [:single_quotes, :numeric_literals, :boolean_literals, :hexadecimal_literals,
                              :comments, :multi_line_comments],
              :oracle     => [:single_quotes, :oracle_quoted_strings, :numeric_literals, :comments,
                              :multi_line_comments],
              :cassandra  => [:single_quotes, :uuids, :numeric_literals, :boolean_literals,
                              :hexadecimal_literals, :comments, :multi_line_comments]
          }

          # We use these to check whether the query contains any quote characters
          # after obfuscation. If so, that's a good indication that the original
          # query was malformed, and so our obfuscation can't reliably find
          # literals. In such a case, we'll replace the entire query with a
          # placeholder.
          CLEANUP_REGEX = {
              :mysql => /'|"|\/\*|\*\//,
              :mysql2 => /'|"|\/\*|\*\//,
              :postgres => /'|\/\*|\*\/|\$(?!\?)/,
              :sqlite => /'|\/\*|\*\//,
              :cassandra => /'|\/\*|\*\//,
              :oracle => /'|\/\*|\*\//,
              :oracle_enhanced => /'|\/\*|\*\//
          }


          QUOTED_STRINGS_REGEX = /'(?:[^']|'')*'|"(?:[^"]|"")*"/
          LABEL_LINE_REGEX     = /^([^:\n]*:\s+).*$/.freeze


          def obfuscate_postgres_explain(sql)
            sql.gsub!(QUOTED_STRINGS_REGEX) do |match|
              match.start_with?('"') ? match : '?'
            end

            sql.gsub!(LABEL_LINE_REGEX,   '\1?')
            sql
          end


          PLACEHOLDER = '?'.freeze
          FAILED_TO_OBFUSCATE_MESSAGE = "Failed to obfuscate SQL query - quote characters remained after obfuscation".freeze



          def obfuscate_single_quote_literals(sql)
            return sql unless sql =~ COMPONENTS_REGEX_MAP[:single_quotes]
            sql.gsub(COMPONENTS_REGEX_MAP[:single_quotes], PLACEHOLDER)
          end

          def self.generate_regex(dialect)
            components = DIALECT_COMPONENTS[dialect]
            Regexp.union(components.map{|component| COMPONENTS_REGEX_MAP[component]})
          end

          MYSQL_COMPONENTS_REGEX = self.generate_regex(:mysql)
          POSTGRES_COMPONENTS_REGEX = self.generate_regex(:postgres)
          SQLITE_COMPONENTS_REGEX = self.generate_regex(:sqlite)
          ORACLE_COMPONENTS_REGEX = self.generate_regex(:oracle)
          CASSANDRA_COMPONENTS_REGEX = self.generate_regex(:cassandra)
          FALLBACK_REGEX = self.generate_regex(:fallback)

          def obfuscate(sql, adapter)
            case adapter
              when :mysql, :mysql2
                regex = MYSQL_COMPONENTS_REGEX
              when :postgres
                regex = POSTGRES_COMPONENTS_REGEX
              when :sqlite
                regex = SQLITE_COMPONENTS_REGEX
              when :oracle, :oracle_enhanced
                regex = ORACLE_COMPONENTS_REGEX
              when :cassandra
                regex = CASSANDRA_COMPONENTS_REGEX
              else
                regex = FALLBACK_REGEX
            end
            obfuscated = sql.gsub(regex, PLACEHOLDER)
            obfuscated = FAILED_TO_OBFUSCATE_MESSAGE if detect_unmatched_pairs(obfuscated, adapter)
            obfuscated
          end

          def detect_unmatched_pairs(obfuscated, adapter)
            if CLEANUP_REGEX[adapter]
              CLEANUP_REGEX[adapter].match(obfuscated)
            else
              CLEANUP_REGEX[:mysql].match(obfuscated)
            end
          end
        end
        include ObfuscationHelpers
      end
    end
  end
end
