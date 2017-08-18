# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

#

module TingYun
  module Agent
    module InstanceMethods
      module HandleErrors
        # When the server sends us an error with the license key, we
        # want to tell the user that something went wrong, and let
        # them know where to go to get a valid license key
        #
        # After this runs, it disconnects the agent so that it will
        # no longer try to connect to the server, saving the
        # application and the server load
        def handle_license_error(error)
          TingYun::Agent.logger.error(\
              error.message, \
              "You need to obtain a valid license key, or to upgrade your account.")
          disconnect
        end

        def handle_unrecoverable_agent_error(error)
          TingYun::Agent.logger.error(error.message)
          disconnect
          shutdown
        end

        # When we have a problem connecting to the server, we need
        # to tell the user what happened, since this is not an error
        # we can handle gracefully.
        def log_error(error)
          TingYun::Agent.logger.error "Error establishing connection with Ting Yun Service at #{service.inspect}:", error
        end

        # Handles an unknown error in the worker thread by logging
        # it and disconnecting the agent, since we are now in an
        # unknown state.
        def handle_other_error(error)
          TingYun::Agent.logger.error "Unhandled error in worker thread, disconnecting this agent process:"
          # These errors are fatal (that is, they will prevent the agent from
          # reporting entirely), so we really want backtraces when they happen
          TingYun::Agent.logger.log_exception(:error, error)
          disconnect
        end

        # Handles the case where the server tells us to restart -
        # this clears the data, clears connection attempts, and
        # waits a while to reconnect.
        def handle_force_restart(error)
          TingYun::Agent.logger.debug error.message
          drop_buffered_data
          @service.force_restart if @service
          @connect_state = :pending
        end

        def handle_delay_restart(error, sec)
          handle_force_restart(error)
          sleep sec
        end

        def handle_force_disconnect(error)
          TingYun::Agent.logger.warn "Ting Yun forced this agent to disconnect (#{error.message})"
          disconnect
        end

        def handle_server_error(error)
          TingYun::Agent.logger.error(error.message)
          drop_buffered_data
        end

      end
    end
  end
end