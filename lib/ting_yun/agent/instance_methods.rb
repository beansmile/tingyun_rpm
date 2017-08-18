# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/agent/instance_methods/start'
require 'ting_yun/agent/instance_methods/connect'
require 'ting_yun/agent/instance_methods/start_worker_thread'
require 'ting_yun/agent/instance_methods/container_data_manager'

module TingYun
  module Agent
    module InstanceMethods

      include Start
      include Connect
      include ContainerDataManager
      include StartWorkerThread



      def reset_to_default_configuration
        TingYun::Agent.config.remove_config_type(:manual)
        TingYun::Agent.config.remove_config_type(:server)
      end

      def stop_event_loop
        @event_loop.stop if @event_loop
      end


      def push_trace_execution_flag(flag =false)
        TransactionState.tl_get.push_traced(flag)
      end

      def pop_trace_execution_flag
        TransactionState.tl_get.pop_traced
      end

    end
  end
end