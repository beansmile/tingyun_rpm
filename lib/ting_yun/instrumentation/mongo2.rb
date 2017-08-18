# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/instrumentation/support/method_instrumentation'

module TingYun
  module Instrumentation
    module Mongo2
      def self.install_mongo_command_log_subscriber
        require 'ting_yun/instrumentation/mongo_command_log_subscriber'
        ::Mongo::Monitoring::Global.subscribe(
            ::Mongo::Monitoring::COMMAND,
            TingYun::Instrumentation::MongoCommandLogSubscriber.new
        )
      end
    end
  end
end



TingYun::Support::LibraryDetection.defer do
  named :mongo2

  depends_on do
    !::TingYun::Agent.config[:disable_mongo]
  end

  depends_on do
    require 'ting_yun/agent/datastore/mongo'
    defined?(::Mongo) && TingYun::Agent::Datastore::Mongo.unsupported_2x? && defined?(::Mongo::Monitoring::Global)
  end

  executes do
    TingYun::Agent.logger.info 'Installing Mongo2 instrumentation'
  end

  executes do
    TingYun::Instrumentation::Mongo2.install_mongo_command_log_subscriber
  end
end
