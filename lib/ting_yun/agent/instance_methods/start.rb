# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/frameworks'
require 'ting_yun/version'

# before the real start,do check and log things
module TingYun
  module Agent
    module InstanceMethods
      module Start

        # Check to see if the agent should start, returning +true+ if it should.
        # should hava the vaild app_name, unstart-state and able to start
        # The agent is disabled when it is not force enabled by the
        # 'nbs.agent_enabled' option (e.g. in a manual start), or
        # enabled normally through the configuration file
        def agent_should_start?
          return false if already_started? || !TingYun::Agent.config[:'nbs.agent_enabled']
          unless app_name_configured?
            TingYun::Agent.logger.error "No application name configured.",
                               "The Agent cannot start without at least one. Please check your ",
                               "tingyun.yml and ensure that it is valid and has at least one ",
                               "value set for app_name in the",
                               "environment."
            return false
          end
          return true
        end

        def started?
          @started
        end

        # Check whether we have already started, which is an error condition
        def already_started?
          if started?
            TingYun::Agent.logger.info("Agent Started Already!")
            true
          end
        end


        def log_startup
          Agent.logger.info "Environment: #{::TingYun::Frameworks.framework.env}" # log_environment
          dispatcher_name = TingYun::Agent.config[:dispatcher].to_s
          if dispatcher_name.empty?
            TingYun::Agent.logger.info 'No known dispatcher detected.'
          else
            TingYun::Agent.logger.info "Dispatcher: #{dispatcher_name}"
          end # log_dispatcher
          TingYun::Agent.logger.info "Application: #{TingYun::Agent.config.app_names.join(", ")}" # log_app_name
        end


        # A correct license key exists and is of the proper length
        def has_correct_license_key?
          if TingYun::Agent.config[:license_key] && TingYun::Agent.config[:license_key].length > 0
            true
          else
            TingYun::Agent.logger.warn("No license key found. " +
                                           "This often means your tingyun.yml file was not found, or it lacks a section for the running environment,'#{::TingYun::Frameworks.framework.env}'. You may also want to try linting your tingyun.yml to ensure it is valid YML.")
            false
          end
        end

        # Logs the configured application names
        def app_name_configured?
          names = TingYun::Agent.config.app_names
          return names.respond_to?(:any?) && names.any?
        end


        # If we're using a dispatcher that forks before serving
        # requests, we need to wait until the children are forked
        # before connecting, otherwise the parent process sends useless data
        def is_using_forking_dispatcher?
          if [:puma, :passenger, :rainbows, :unicorn].include? TingYun::Agent.config[:dispatcher]
            TingYun::Agent.logger.info "Deferring startup of agent reporting thread because #{TingYun::Agent.config[:dispatcher]} may fork."
            true
          else
            false
          end
        end

        # Sanity-check the agent configuration and start the agent,
        # setting up the worker thread and the exit handler to shut
        # down the agent
        def check_config_and_start_agent
          return unless  has_correct_license_key?
          return if is_using_forking_dispatcher?
          setup_and_start_agent
        end

        # This is the shared method between the main agent startup and the
        # after_fork call restarting the thread in deferred dispatchers.
        #
        # Treatment of @started and env report is important to get right.
        def setup_and_start_agent(options={})
          @started = true
          @dispatcher.mark_started
          generate_environment_report
          install_exit_handler
          @middleware.load_samplers # cpu and memory load

          if TingYun::Agent.config[:sync_startup]
            connect_in_sync
          else
            start_worker_thread(options)
          end
        end

        # This method should be called in a forked process after a fork.
        # It assumes the parent process initialized the agent, but does
        # not assume the agent started.
        #
        # The call is idempotent, but not re-entrant.
        #
        # * It clears any metrics carried over from the parent process
        # * Restarts the sampler thread if necessary
        # * Initiates a new agent run and worker loop unless that was done
        #   in the parent process and +:force_reconnect+ is not true
        #
        # Options:
        # * <tt>:force_reconnect => true</tt> to force the spawned process to
        #   establish a new connection, such as when forking a long running process.
        #   The default is false--it will only connect to the server if the parent
        #   had not connected.
        # * <tt>:keep_retrying => false</tt> if we try to initiate a new
        #   connection, this tells me to only try it once so this method returns
        #   quickly if there is some kind of latency with the server.
        def after_fork(options={})
          needs_restart = false
          @after_fork_lock.synchronize do
            needs_restart = @dispatcher.needs_restart?
            @dispatcher.mark_started
          end

          return if !needs_restart ||
              !Agent.config[:'nbs.agent_enabled'] || disconnected?

          ::TingYun::Agent.logger.debug "Starting the worker thread in #{Process.pid} (parent #{Process.ppid}) after forking."

          # Clear out locks and stats left over from parent process
          reset_objects_with_locks
          drop_buffered_data

          setup_and_start_agent(options)
        end


      end
    end
  end
end