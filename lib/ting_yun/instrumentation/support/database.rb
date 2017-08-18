# encoding: utf-8

require 'ting_yun/support/helper'

module TingYun
  module Instrumentation
    module Support
      module  Database
        extend self

        KNOWN_OPERATIONS = [
            'SELECT',
            'UPDATE',
            'DELETE',
            'INSERT',
            'SHOW',
            'CALL',
            'PRAGMA'
        ]

        SQL_COMMENT_REGEX = Regexp.new('/\*.*?\*/', Regexp::MULTILINE).freeze
        EMPTY_STRING      = ''.freeze

        def parse_operation_from_query(sql)
          sql =TingYun::Helper.correctly_encoded(sql).gsub(SQL_COMMENT_REGEX, EMPTY_STRING)
          if sql =~ /(\w+)/
            op = $1.upcase
            if KNOWN_OPERATIONS.include?(op)
              return op
            else
              return "CALL"
            end
          end
        end
      end
    end
  end
end

