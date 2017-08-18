# encoding: utf-8
require 'ting_yun/agent/transaction'
require 'ting_yun/agent/transaction/transaction_state'

TingYun::Support::LibraryDetection.defer do
  named :grape

  depends_on do
    defined?(::Grape) && defined?(::Grape::Endpoint)
  end

  executes do
    TingYun::Agent.logger.info 'Installing grape instrumentation'
  end


  executes do
    ::Grape::Endpoint.class_eval do
      def run_with_tingyun(*args)
        begin
          name = ["Grape",
                  self.options[:method].first,
                  self.options[:for].to_s,
                  self.namespace.sub(%r{\A/}, ''), # removing leading slashes
                  self.options[:path].first.sub(%r{\A/}, ''),
          ].compact.select{ |n| n.to_s unless n.to_s.empty? }.join("/")
          TingYun::Agent::Transaction.set_default_transaction_name(name, :controller)
          run_without_tingyun(*args)
        rescue => e
          TingYun::Agent.logger.info("Error getting Grape Endpoint Name. Error: #{e.message}. Options: #{self.options.inspect}")
        end

      end
      alias run_without_tingyun run
      alias run run_with_tingyun
    end

  end
end
