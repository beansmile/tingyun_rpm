# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

#

module TingYun
  module Support
    module Exception

      # An exception that is thrown by the server, drop the data.
      class UnKnownServerException < StandardError;
      end

      # Used to blow out of a periodic task without logging a an error, such as for routine
      # failures.
      class ServerConnectionException < StandardError;
      end

      # When a post is either too large or poorly formatted we should
      # drop it and not try to resend
      class UnrecoverableServerException < ServerConnectionException;
      end

      # An unrecoverable client-side error that prevents the agent from continuing
      class UnrecoverableAgentException < ServerConnectionException;
      end

      # An error while serializing data for the collector
      class SerializationError < StandardError;
      end

      class AppSessionKeyError < StandardError;
      end
      #This is the base class for all errors that we want to record , It provides the
      # standard support text at the front of the message, and is used for flagging
      # agent errors when checking queue limits.
      class InternalAgentError < StandardError
        def initialize(msg=nil)
          super("Ruby agent internal error. Please contact support referencing this error.\n #{msg}")
        end
      end

      #跨应用错误
      class InternalServerError < StandardError

      end

    end
  end
end