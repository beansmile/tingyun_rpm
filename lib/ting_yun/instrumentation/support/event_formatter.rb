# encoding: utf-8

module TingYun
  module Instrumentation
    module Support
      module EventFormatter
        def self.format(command_name, database_name, command)
          result = {
              :operation => command_name,
              :database => database_name,
              :collection => command.values.first,
              :term => command.values.last
          }
          result
        end
      end
    end
  end
end
