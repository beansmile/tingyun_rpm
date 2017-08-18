# encoding: utf-8
require 'ting_yun/agent'
require 'ting_yun/support/local_environment'
require 'ting_yun/frameworks'


module TingYun
  module Frameworks
    module ClassMethods
      def instance
        framework = TingYun::Agent.config[:framework]
        if framework == :test
          @instance ||= load_test_framework
        else
          @instance ||= load_framework_class(framework).new(local_env)
        end

      end

      def load_test_framework
        config = File.expand_path(File.join('..','..', 'test','config','tingyun.yml'), __FILE__)
        require 'config/test'
        TingYun::Frameworks::Test.new(local_env, config)
      end


      def load_framework_class(framework)
        begin
          require 'ting_yun/frameworks/' + framework.to_s
        rescue LoadError
          #to avoid error
        end
        TingYun::Frameworks.const_get(framework.to_s.capitalize)
      end

      def local_env
        @local_env ||= TingYun::Support::LocalEnvironment.new
      end

      # clear out memoized Framework and LocalEnv instances
      def reset
        @instance = nil
        @local_env = nil
      end
    end
  end
end