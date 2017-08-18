# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/support/exception'
require 'ting_yun/support/hostname'
require 'ting_yun/configuration/server_source'
require 'ting_yun/agent/instance_methods/handle_errors'
require 'ting_yun/environment_report'


module TingYun
  module Agent
    module InstanceMethods
      module Connect

        include HandleErrors



        # Disconnect just sets connected to false, which prevents
        # the agent from trying to connect again
        # @connect_state has three state {:disconnected,:pending,:connected}

        def disconnect
          @connect_state = :disconnected
          true
        end

        def connected?
          @connect_state == :connected
        end

        def disconnected?
          @connect_state == :disconnected
        end

        # Don't connect if we're already connected, or if we tried to connect
        # and were rejected with prejudice because of a license issue, unless
        # we're forced to by force_reconnect.
        def should_connect?(force=false)
          force || (!connected? && !disconnected?)
        end


        def generate_environment_report
          @environment_report = environment_for_connect
        end

        # We've seen objects in the environment report (Rails.env in
        # particular) that can't seralize to JSON. Cope with that here and
        # clear out so downstream code doesn't have to check again.
        def sanitize_environment_report
          if !@service.valid_to_marshal?(@environment_report)
            @environment_report = {}
          end
        end


        # Checks whether we should send environment info, and if so,
        # returns the snapshot from the local environment.
        # Generating the EnvironmentReport has the potential to trigger
        # require calls in Rails environments, so this method should only
        # be called synchronously from on the main thread.
        def environment_for_connect
          ::TingYun::Agent.config[:send_environment_info] ? TingYun::EnvironmentReport.new.data : {}
        end


        # Initializes the hash of settings that we send to the
        # server. Returns a literal hash containing the options
        def connect_settings
          sanitize_environment_report
          settings = {
              :pid => $$,
              :port => ::TingYun::Agent.config[:port],
              :host => local_host,
              :appName => ::TingYun::Agent.config.app_names,
              :language => 'Ruby',
              :agentVersion => ::TingYun::VERSION::STRING,
              :env => @environment_report,
              :config => ::TingYun::Agent.config.to_collector_hash
          }
          settings
        end

        def local_host
          TingYun::Support::Hostname.get
        end

        # Returns connect data passed back from the server
        def connect_to_server
          @service.connect(connect_settings)
        end

        #merge server config
        def query_server_for_configuration
          finish_setup(connect_to_server)
        end

        # * <tt>:keep_retrying => false</tt> to only try to connect once, and
        #   return with the connection set to nil.  This ensures we may try again
        #   later (default true).
        # * <tt>force_reconnect => true</tt> if you want to establish a new connection
        #   to the server before running the worker loop.  This means you get a separate
        #   agent run and Ting Yun sees it as a separate instance (default is false).
        def catch_errors
          yield
        rescue  TingYun::Support::Exception::UnKnownServerException => e
          handle_force_restart(e)
          retry
        rescue TingYun::Support::Exception::ServerConnectionException => e
          handle_delay_restart(e, 60)
          retry
        rescue => e
          handle_delay_restart(e, 60)
          retry
        end

        # Takes a hash of configuration data returned from the
        # server and uses it to set local variables and to
        # initialize various parts of the agent that are configured
        # separately.
        #
        def finish_setup(config_data)
          return if config_data == nil

          if config_data['config']
            ::TingYun::Agent.logger.debug "Using config from server"
          end
          ::TingYun::Agent.logger.debug "Server provided config: #{config_data.inspect}"
          server_config = TingYun::Configuration::ServerSource.new(config_data)
          ::TingYun::Agent.config.replace_or_add_config(server_config)
          #log_connection!(config_data)
        end

        def log_connection!(config_data)
          ::TingYun::Agent.logger.debug "Connected to TingYun Service at #{@service.collector.name}"
          ::TingYun::Agent.logger.debug "Application Run       = #{@service.applicationId}."
          ::TingYun::Agent.logger.debug "Connection data = #{config_data.inspect}"
          if config_data['messages'] && config_data['messages'].any?
            log_collector_messages(config_data['messages'])
          end
        end

        def log_collector_messages(messages)
          messages.each do |message|
            ::TingYun::Agent.logger.send(message['level'].downcase, message['message'])
          end
        end

        def connect_in_sync
          TingYun::Agent.disable_all_tracing { connect!(:keep_retrying => false) }
        end
      end
    end
  end
end