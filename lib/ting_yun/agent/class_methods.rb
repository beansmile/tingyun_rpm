# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/agent'

module TingYun
  module Agent
    module ClassMethods
      def config
        ::TingYun::Agent.config
      end

      def logger
        ::TingYun::Agent.logger
      end

      def instance
        @instance ||= new
      end
    end
  end
end