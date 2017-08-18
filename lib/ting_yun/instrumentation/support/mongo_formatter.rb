# encoding: utf-8


require 'ting_yun/agent/datastores/mongo/obfuscator'

module TingYun
  module Instrumentation
    module Support
      module MongoFormatter

        PLAINTEXT_KEYS = [
            :database,
            :collection,
            :operation,
            :fields,
            :skip,
            :limit,
            :order
        ]

        OBFUSCATE_KEYS = [
            :selector
        ]

        def self.format(statement, operation)

          result = {:operation => operation}

          PLAINTEXT_KEYS.each do |key|
            result[key] = statement[key] if statement.key?(key)
          end

          OBFUSCATE_KEYS.each do |key|
            if statement.key?(key) && statement[key]
              obfuscated = obfuscate(statement[key])
              result[key] = obfuscated if obfuscated
            end
          end
          result
        end

        def self.obfuscate(statement)
          statement = Obfuscator.obfuscate_statement(statement)
          statement
        end
      end
    end
  end
end
