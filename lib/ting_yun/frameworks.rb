# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/frameworks/instance_methods'
require 'ting_yun/frameworks/class_methods'
require 'yaml'

module TingYun
  module Frameworks

    def self.framework
      Framework.instance
    end

    def self.init_start(options={})
      framework.init_plugin(options)
    end


    class Framework
      include InstanceMethods
      extend ClassMethods

      protected

      def initialize(local_env,config_file_override=nil)
        @local_env = local_env
        @started_in_env = nil
        @config_file_override = config_file_override

        @instrumentation_files = []
      end
    end
  end
end

