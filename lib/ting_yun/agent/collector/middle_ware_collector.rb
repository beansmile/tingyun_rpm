# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/agent/collector/middle_ware_collector/sampler'


module TingYun
  module Agent
    module Collector
      class MiddleWareCollector

        include Enumerable

        def initialize(event_listener)
          @samplers = []
          @event_listener = event_listener
          @event_listener.subscribe(:middleware_harvest) { samplers_poll }
        end

        def samplers_poll
          @samplers.delete_if do |sampler|
            begin
              sampler.poll
              false # it's okay.  don't delete it.
            rescue => e
              ::TingYun::Agent.logger.warn("Removing #{sampler} from list", e)
              true # remove the sampler
            end
          end
        end

        def each(&blk)
          @samplers.each(&blk)
        end

        def clear()
          @samplers.clear
        end

        def sampler_class_registered?(sampler_class)
          self.any? { |s| s.class == sampler_class }
        end

        def register_sampler(sampler_class)
          supported = sampler_class.supported_on_this_platform?
          enabled = sampler_class.enabled?
          if supported && enabled
            if !sampler_class_registered?(sampler_class)
              sampler = sampler_class.new

              @samplers << sampler
              ::TingYun::Agent.logger.debug("Registered #{sampler_class.name} for harvest time sampling.")
            else
              ::TingYun::Agent.logger.warn("Ignoring addition of #{sampler_class.name} because it is already registered.")
            end
          else
            ::TingYun::Agent.logger.debug("#{sampler_class.name} not supported on this platform.")
          end
        rescue TingYun::Agent::Collector::Sampler::Unsupported => e
          ::TingYun::Agent.logger.info("#{sampler_class.name} not available: #{e}")
        rescue => e
          ::TingYun::Agent.logger.error("Error registering sampler:", e)
        end


        # adds samplers to the sampler collection so that they run every
        # minute. This is dynamically recognized by any class that
        def load_samplers
          TingYun::Agent::Collector::Sampler.sampler_classes.each do |subclass|
            register_sampler(subclass)
          end
        end
      end
    end
  end
end



