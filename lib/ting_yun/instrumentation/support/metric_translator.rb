# encoding: utf-8
require 'ting_yun/agent'
require 'ting_yun/agent/datastore/metric_helper'
require 'ting_yun/agent/datastore/mongo'

module TingYun
  module Instrumentation
    module Support
      module MetricTranslator

        MONGODB = 'MongoDB'.freeze

        def self.metrics_for(name, payload, host_port)
          payload ||= {}

          return nil  if collection_in_selector?(payload)

          collection = payload[:collection]

          if create_index?(name, payload)
            collection = self.collection_name_from_index(payload)
          elsif group?(name, payload)
            collection = collection_name_from_group_selector(payload)
          elsif rename_collection?(name, payload)
            collection = collection_name_from_rename_selector(payload)
          end

          TingYun::Agent::Datastore::MetricHelper.metrics_for(MONGODB,
                                                              TingYun::Agent::Datastore::Mongo.transform_operation(name),
                                                              host_port[0],
                                                              host_port[1],
                                                              payload[:database],
                                                              collection)
        rescue => e
          TingYun::Agent.logger.debug("Failure during Mongo metric generation", e)
          nil
        end


        def self.collection_in_selector?(payload)
          payload[:collection] == '$cmd'
        end

        def self.create_index?(name, payload)
          name == :insert && payload[:collection] == "system.indexes"
        end

        def self.group?(name, payload)
          name == :group
        end

        def self.rename_collection?(name, payload)
          name == :renameCollection
        end

        def self.collection_name_from_index(payload)
          if payload[:documents]
            if payload[:documents].is_a?(Array)
              # mongo gem versions pre 1.10.0
              document = payload[:documents].first
            else
              # mongo gem versions 1.10.0 and later
              document = payload[:documents]
            end

            if document && document[:ns]
              return document[:ns].split('.').last
            end
          end

          'system.indexes'
        end

        def self.collection_name_from_group_selector(payload)
          payload[:selector]["group"]["ns"]
        end

        def self.collection_name_from_rename_selector(payload)
          parts = payload[:selector][:renameCollection].split('.')
          parts.shift
          parts.join('.')
        end

      end
    end
  end
end
