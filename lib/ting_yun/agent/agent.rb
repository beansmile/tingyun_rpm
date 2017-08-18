# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/logger/agent_logger'
require 'ting_yun/agent/class_methods'
require 'ting_yun/agent/instance_methods'
require 'ting_yun/ting_yun_service'
require 'ting_yun/frameworks'
require 'ting_yun/agent/event/event_listener'
require 'ting_yun/agent/dispatcher'
require 'ting_yun/agent/collector/middle_ware_collector'
require 'ting_yun/agent/cross_app/cross_app_monitor'
require 'ting_yun/agent/collector/transaction_sampler'


# The Agent is a singleton that is instantiated when the plugin is
# activated.  It collects performance data from ruby applications
# in realtime as the application runs, and periodically sends that
# data to the  server. TingYun::Agent::Agent.instance

module TingYun
  module Agent
    class Agent

      class << self
        private :new
      end

      # service for communicating with collector
      attr_accessor :service, :cross_app_monitor, :middleware
      attr_reader :events

      extend ClassMethods
      include InstanceMethods


      def initialize
        @started = false
        @environment_report = nil
        @service = TingYunService.new
        @connect_state = :pending #[:pending, :connected, :disconnected]
        @events  = TingYun::Agent::Event::EventListener.new
        @after_fork_lock = Mutex.new
        @dispatcher = TingYun::Agent::Dispatcher.new(@events)
        @cross_app_monitor = TingYun::Agent::CrossAppMonitor.new(@events)
        @middleware = TingYun::Agent::Collector::MiddleWareCollector.new(@events)

        init_containers
      end

      def start
        # should hava the vaild app_name, unstart-state and able to start
        return unless agent_should_start?
        log_startup
        check_config_and_start_agent
        TingYun::Agent.logger.debug "Ting Yun Ruby Agent #{TingYun::VERSION::STRING} Initialized: pid = #{$$}" # log_version_and_pid
      end

      # Attempt a graceful shutdown of the agent, flushing any remaining
      # data.
      def shutdown
        return unless started?
        TingYun::Agent.logger.info "Starting Agent shutdown"

        stop_event_loop
        untraced_graceful_disconnect
        reset_to_default_configuration

        @started = nil

        TingYun::Frameworks::Framework.reset
      end

      # Connect to the server and validate the license.  If successful,
      # connected? returns true when finished.  If not successful, you can
      # keep calling this.  Return false if we could not establish a
      # connection with the server and we should not retry, such as if
      # there's a bad license key.

      def connect!(option={})
        defaults = {
            :force_reconnect => ::TingYun::Agent.config[:force_reconnect],
            :keep_retrying => ::TingYun::Agent.config[:keep_retrying]
        }
        opts = defaults.merge(option)
        return unless should_connect?(opts[:force_reconnect])
        TingYun::Agent.logger.debug "Connecting Process to Ting Yun: #$0"
        query_server_for_configuration
        @connect_state = :connected
      rescue Exception => error
        ::TingYun::Agent.logger.error "Exception of unexpected type during Agent#connect! :", error
        log_error(error)
        if opts[:keep_retrying]
          ::TingYun::Agent.logger.info "Will re-attempt in 60 seconds"
          raise
        end
      end

      def sinatra_classic_app?
        defined?(::Sinatra::Base) && ::Sinatra::Base.respond_to?(:run!)
      end

      def should_install_exit_handler?
        !sinatra_classic_app?
      end

      def install_exit_handler
        return unless should_install_exit_handler?
        TingYun::Agent.logger.debug("Installing at_exit handler")
        at_exit do
          if defined?(RUBY_ENGINE) && RUBY_ENGINE == "ruby" && RUBY_VERSION.match(/^1\.9/)
            exit_status = $!.status if $!.is_a?(SystemExit)
            shutdown
            exit exit_status if exit_status
          else
            shutdown
          end
        end
      end


      def untraced_graceful_disconnect
        begin
          TingYun::Agent.disable_all_tracing do
            if connected?
              transmit_data
            end
          end
        rescue => error
          ::TingYun::Agent.logger.error error
        end
      end


    end
  end
end