# encoding: utf-8
require 'ting_yun/instrumentation/middleware_proxy'

module TingYun
  class AgentMiddleware

    include TingYun::Instrumentation::MiddlewareTracing

    attr_reader :transaction_options, :category, :target

    def initialize(app)
      @app = app
      @category = :middleware
      @target   = self
      @transaction_options = {
          :transaction_name => build_transaction_name
      }
    end

    def build_transaction_name
      prefix = ::TingYun::Instrumentation::Support::TransactionNamer.prefix_for_category(nil, @category)
      "#{prefix}#{self.class.name}/call"
    end



  end
end
