# encoding: utf-8
require 'ting_yun/support/version_number'
module TingYun
  module Agent
    module Datastore
      module Mongo

        def self.monitoring_enabled?
          defined?(::Mongo::Monitoring)
        end

        def self.version_1_10_or_later?
          # Again, no VERSION constant in 1.x, so we have to rely on constant checks
          defined?(::Mongo::CollectionOperationWriter)
        end

        def self.unsupported_2x?
          defined?(::Mongo::VERSION) && TingYun::Support::VersionNumber.new(::Mongo::VERSION).major_version == 2
        end

        def self.supported_version?
          # No version constant in < 2.0 versions of Mongo :(
          defined?(::Mongo) && (defined?(::Mongo::MongoClient) || monitoring_enabled?)
        end

        # def self.transform_operation(operation)
        #   t_operation = case operation.to_s.upcase
        #                 when 'DELETE', 'FIND_AND_REMOVE', 'DELETEINDEXS', 'REMOVE'                       then 'destroy'
        #                 when 'INSERT'                                                                    then 'INSERT'
        #                 when 'UPDATE', 'RENAMECOLLECTION', 'REINDEX'                                     then 'UPDATE'
        #                 when 'CREATE', 'FIND_AND_MODIFY', 'CREATEINDEXS', 'CREATEINDEX', 'REPINDEX'      then 'SAVE'
        #                 when 'QUERY', 'COUNT', 'GET_MORE', 'AGGREGATE', 'FIND', 'FINDONE', 'GROUP'       then 'SECECT'
        #                 else
        #                   nil
        #                 end
        #   t_operation
        # end
        def self.transform_operation(operation)
          operation.to_s.upcase
        end
      end
    end
  end
end
