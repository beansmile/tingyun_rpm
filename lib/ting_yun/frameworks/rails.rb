# encoding: utf-8

require 'ting_yun/frameworks/ruby'

module TingYun
  module Frameworks
    # noinspection ALL
    class Rails < TingYun::Frameworks::Ruby

      def env
        @evn ||= RAILS_ENV.dup
      end

      def root
        root = rails_root.to_s.empty? ? super : rails_root.to_s
      end

      # noinspection Rails3Deprecated,Rails3Deprecated
      def rails_root
        RAILS_ROOT if defined?(RAILS_ROOT)
      end

      def rails_config
        if defined?(::Rails) && ::Rails.respond_to?(:configuration)
          ::Rails.configuration
        else
          @config
        end
      end

      # In versions of Rails prior to 2.0, the rails config was only available to
      # the init.rb, so it had to be passed on from there.  This is a best effort to
      # find a config and use that.
      def init_config(options = {})
        @config = options[:config]
        # Install the dependency detection,
        if rails_config && ::Rails.configuration.respond_to?(:after_initialize)
          rails_config.after_initialize do
            # This will insure we load all the instrumentation as late as possible.  If the agent
            # is not enabled, it will load a limited amount of instrumentation.
            TingYun::Support::LibraryDetection.detect!
          end
        end

        if !Agent.config[:'nbs.agent_enabled']
          # Might not be running if it does not think mongrel, thin, passenger, etc
          # is running, if it thinks it's a rake task, or if the nbs.agent_enabled is false.
          ::TingYun::Agent.logger.info("TingYun Agent is unable to run.")
        else
          install_browser_monitoring(rails_config)
        end
      rescue => e
        ::TingYun::Agent.logger.error("Failure during init_config for Rails. Is Rails required in a non-Rails app? Set TING_YUN_FRAMEWORK=ruby to avoid this message.",
                                       "The Ruby agent will continue running, but Rails-specific features may be missing.",
                                       e)
      end

      def install_browser_monitoring(config)
        return if @browser_monitoring_installed
        @browser_monitoring_installed = true
        return if config.nil? || !config.respond_to?(:middleware)
        begin
          require 'ting_yun/middleware/browser_monitoring'
          config.middleware.use TingYun::BrowserMonitoring
          ::TingYun::Agent.logger.debug("Installed TingYun Browser Monitoring middleware")
        rescue => e
          ::TingYun::Agent.logger.error("Error installing TingYun Browser Monitoring middleware", e)
        end
      end

      protected

      def rails_vendor_root
        File.join(root,'vendor','rails')
      end
    end
  end
end