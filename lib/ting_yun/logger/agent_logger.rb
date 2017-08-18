# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'thread'
require 'logger'
require 'ting_yun/logger/log_once'
require 'ting_yun/logger/memory_logger'
require 'ting_yun/support/hostname'
require 'ting_yun/logger/null_logger'
require 'ting_yun/logger/create_logger_helper'

module TingYun
  module Logger
    class AgentLogger
      include ::TingYun::Logger::LogOnce
      include ::TingYun::Logger::CreateLoggerHelper

      attr_reader :file_path
      def initialize(root = "", override_logger=nil)
        @already_logged_lock = Mutex.new
        clear_already_logged
        create_log(root, override_logger)
        set_log_level
        set_log_format

        gather_startup_logs
      end

      def fatal(*msgs, &blk)
        format_and_send(:fatal, msgs, &blk)
      end

      def error(*msgs, &blk)
        format_and_send(:error, msgs, &blk)
      end

      def warn(*msgs, &blk)
        format_and_send(:warn, msgs, &blk)
      end

      def info(*msgs, &blk)
        format_and_send(:info, msgs, &blk)
      end

      def debug(*msgs, &blk)
        format_and_send(:debug, msgs, &blk)
      end

      def is_startup_logger?
        @log.is_a?(NullLogger)
      end

      # Use this when you want to log an exception with explicit control over
      # the log level that the backtrace is logged at. If you just want the
      # default behavior of backtraces logged at debug, use one of the methods
      # above and pass an Exception as one of the args.
      def log_exception(level, e, backtrace_level=level)
        @log.send(level, "%p: %s" % [e.class, e.message])
        @log.send(backtrace_level) do
          backtrace = backtrace_from_exception(e)
          if backtrace
            "Debugging backtrace:\n" + backtrace.join("\n  ")
          else
            "No backtrace available."
          end
        end
      end


      private

      def backtrace_from_exception(e)
        # We've seen that often the backtrace on a SystemStackError is bunk
        # so massage the caller instead at a known depth.
        #
        # Tests keep us honest about minmum method depth our log calls add.
        return caller.drop(5) if e.is_a?(SystemStackError)

        e.backtrace
      end

      # Allows for passing exception.rb in explicitly, which format with backtrace
      def format_and_send(level, *msgs, &block)
        check_log_file
        if block
          if @log.send("#{level}?")
            msgs = Array(block.call)
          else
            msgs = []
          end
        end

        msgs.flatten.each do |item|
          case item
            when Exception then
              log_exception(level, item, :debug)
            else
              @log.send(level, item)
          end
        end
        nil
      end


      def wants_stdout?
        ::TingYun::Agent.config[:agent_log_file_name].upcase == "STDOUT"
      end



      def set_log_level
        @log.level = AgentLogger.log_level_for(::TingYun::Agent.config[:agent_log_level])
      end

      LOG_LEVELS = {
          "debug" => ::Logger::DEBUG,
          "info" => ::Logger::INFO,
          "warn" => ::Logger::WARN,
          "error" => ::Logger::ERROR,
          "fatal" => ::Logger::FATAL,
      }

      def self.log_level_for(level)
        LOG_LEVELS.fetch(level.to_s.downcase, ::Logger::INFO)
      end

      def set_log_format
        hostname = TingYun::Support::Hostname.get
        prefix = wants_stdout? ? '** [TingYun]' : ''
        @log.formatter = Proc.new do |severity, timestamp, progname, msg|
          "#{prefix}[#{timestamp.strftime("%m/%d/%y %H:%M:%S %z")} #{hostname} (#{$$})] #{severity} : #{msg}\n"
        end
      end

      #send the statup log info from memory to the agent log
      def gather_startup_logs
        StartupLogger.instance.dump(self)
      end

    end
  end
end
