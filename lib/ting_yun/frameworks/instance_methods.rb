# encoding: utf-8
require 'ting_yun/configuration/manual_source'
require 'ting_yun/configuration/yaml_source'
require 'ting_yun/agent'
require 'ting_yun/logger/agent_logger'
require 'ting_yun/agent/agent'
require 'ting_yun/frameworks/instrumentation'

module TingYun
  module Frameworks
    module InstanceMethods

      include ::TingYun::Frameworks::Instrumentation

      # The env is the setting used to identify which section of the tingyun.yml
      # to load.  This defaults to a framework specific value, such as ENV['RAILS_ENV']
      # but can be overridden as long as you set it before calling #init_plugin
      attr_writer :env

      # The local environment contains all the information we report
      # to the server about what kind of application this is, what
      # gems and plugins it uses, and many other kinds of
      # machine-dependent information useful in debugging
      attr_reader :local_env

      # Initialize the plugin/gem and start the agent.  This does the
      # necessary configuration based on the framework environment and
      # determines whether or not to start the agent.  If the agent is
      # not going to be started then it loads the agent shim which has
      # stubs for all the external api.
      #
      # This may be invoked multiple times, as long as you don't attempt
      # to uninstall the agent after it has been started.
      #
      # If the plugin is initialized and it determines that the agent is
      # not enabled, it will skip starting it and install the shim.  But
      # if you later call this with <tt>agent_enabled => true</tt>,
      # then it will install the real agent and start it.
      #
      # What determines whether the agent is launched is the result of
      # calling nbs.agent_enabled?  This will indicate whether the
      # instrumentation should/will be installed.  If we're in a mode
      # where tracers are not installed then we should not start the
      # agent.
      #
      # Subclasses are not allowed to override, but must implement
      # init_config({}) which is called one or more times.
      def init_plugin(options={})
        env = determine_env(options)

        configure_agent(env, options)

        if ::TingYun::Agent.logger.is_startup_logger?
          ::TingYun::Agent.logger = TingYun::Logger::AgentLogger.new(root, options.delete(:log))
        end

        environment_name = options.delete(:env) and self.env = environment_name

        init_config(options)

        TingYun::Agent.agent = TingYun::Agent::Agent.instance

        if TingYun::Agent.config[:'nbs.agent_enabled'] && !TingYun::Agent.agent.started?
          start_agent
          install_instrumentation
        else
          TingYun::Support::LibraryDetection.detect!
        end

      end

      def determine_env(options)
        env = options[:env] || self.env
        env = env.to_s

        if @started_in_env && @started_in_env != env
          TingYun::Agent.logger.error("Attempted to start agent in #{env.inspect} environment, but agent was already running in #{@started_in_env.inspect}",
                             "The agent will continue running in #{@started_in_env.inspect}. To alter this, ensure the desired environment is set before the agent starts.")
        else
          TingYun::Agent.logger.info("Starting the Ting Yun agent in #{env.inspect} environment.",
                            "To prevent agent startup add a TINGYUN_AGENT_ENABLED=false environment variable or modify the #{env.inspect} section of your tingyun.yml.")
        end

        env
      end

      def configure_agent(env, options)
        # manual_source
        TingYun::Agent.config.replace_or_add_config(TingYun::Configuration::ManualSource.new(options)) unless options.empty?

        # yaml_source
        config_file_path = @config_file_override || TingYun::Agent.config[:config_path]
        TingYun::Agent.config.replace_or_add_config(TingYun::Configuration::YamlSource.new(config_file_path,env))
      end

      def start_agent
        @started_in_env = self.env
        TingYun::Agent.agent.start
      end

      def framework
        Agent.config[:framework]
      end

      def [](key)
        TingYun::Agent.config[key.to_sym]
      end

      def dispatcher
        TingYun::Agent.config[:dispatcher]
      end

      def root
        '.'
      end


    end
  end
end