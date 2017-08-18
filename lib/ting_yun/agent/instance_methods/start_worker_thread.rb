# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/agent/threading/agent_thread'
require 'ting_yun/agent/event/event_loop'

module TingYun
  module Agent
    module InstanceMethods
      module StartWorkerThread
        def  start_worker_thread(connection_options={})
          TingYun::Agent.logger.debug "Creating Ruby Agent worker thread."
          @worker_thread = TingYun::Agent::Threading::AgentThread.create('Worker Loop') do
            deferred_work!(connection_options)
          end
        end

        # This is the method that is run in a new thread in order to
        # background the harvesting and sending of data during the
        # normal operation of the agent.
        #
        # Takes connection options that determine how we should
        # connect to the server, and loops endlessly - typically we
        # never return from this method unless we're shutting down
        # the agent
        def deferred_work!(connection_options)
          catch_errors do
            TingYun::Agent.disable_all_tracing do
              connect!(connection_options)
              if connected?
                create_and_run_event_loop
              else
                TingYun::Agent.logger.debug "No connection.  Worker thread ending."
              end
            end
          end
        end

        def create_and_run_event_loop
          @event_loop = TingYun::Agent::Event::EventLoop.new

          @event_loop.on(:report_data) do
            transmit_data
          end
          @event_loop.fire_every(Agent.config[:data_report_period], :report_data)

          @event_loop.on(:create_new_logfile) do
            TingYun::Logger::CreateLoggerHelper.create_new_logfile
          end
          @event_loop.fire_every(TingYun::Agent.config[:agent_log_file_check_days]*60*60*24, :create_new_logfile)

          @event_loop.run
        end
      end
    end
  end
end