# encoding: utf-8

module TingYun
  module Agent
    module Event
      class EventListener

        attr_accessor :allocation

        def initialize
          @events = {}
          @allocation = 100
        end

        def subscribe(event, &handler)
          @events[event] ||= []
          @events[event] << handler
          check_allocation(event)
        end

        def check_allocation(event)
          if @events[event].size > @allocation
            TingYun::Agent.logger.debug("Run-away event subscription on #{event}? Subscribed #{count}")
          end
        end

        def clear
          @events.clear
        end


        def notify(event, *args)
          return unless @events.has_key?(event)

          @events[event].each do |handler|
            begin
              handler.call(*args)
            rescue => err
              TingYun::Agent.logger.debug("Failure during notify for #{event}", err)
            end
          end
        end
      end
    end
  end
end

