# encoding: utf-8

require 'ting_yun/agent'

module TingYun
  module Agent
    module Collector
      class Sampler

        class Unsupported < StandardError;  end

        attr_reader :id
        @sampler_classes = []

        def self.named(new_name)
          @name = new_name
        end

        def self.name
          @name
        end

        def self.inherited(subclass)
          @sampler_classes << subclass
        end

        # Override with check.  Called before instantiating.
        def self.supported_on_this_platform?
          true
        end

        def self.enabled?
          if @name
            config_key = "disable_#{@name}_sampler"
            !(::TingYun::Agent.config[config_key])
          else
            true
          end
        end

        def self.sampler_classes
          @sampler_classes
        end

        # The ID passed in here is unused by our code, but is preserved in case
        # we have clients who are defining their own subclasses of this class, and
        # expecting to be able to call super with an ID.
        def initialize(id=nil)
          @id = id || self.class.name
        end

        def poll
          raise "Implement in the subclass"
        end
      end
    end
  end
end

