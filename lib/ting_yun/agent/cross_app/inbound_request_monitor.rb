# encoding: utf-8

# This class serves as the base for objects wanting to monitor and respond to
# incoming web requests. Examples include cross application tracing and
# synthetics.
#
# Subclasses are expected to define on_finished_configuring(events) which will
# be called when the agent is fully configured. That method is expected to
# subscribe to the necessary request events, such as before_call and after_call
# for the monitor to do its work.

module TingYun
  module Agent
    class InboundRequestMonitor
      def initialize(events)
        events.subscribe(:finished_configuring) do
          on_finished_configuring(events)
        end
      end
    end
  end
end