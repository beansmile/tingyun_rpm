# encoding: utf-8

# Base class for startup logging and testing in multiverse
require 'ting_yun/logger/log_once'

module TingYun
  module Logger
    class MemoryLogger
      include LogOnce

      def initialize
        @already_logged_lock = Mutex.new
        clear_already_logged

        @messages = []
      end

      def is_startup_logger?
        true
      end

      attr_accessor :messages, :level, :log_formatter

      def fatal(*msgs, &blk)
        messages << [:fatal, msgs, blk]
      end

      def error(*msgs, &blk)
        messages << [:error, msgs, blk]
      end

      def warn(*msgs, &blk)
        messages << [:warn, msgs, blk]
      end

      def info(*msgs, &blk)
        messages << [:info, msgs, blk]
      end

      def debug(*msgs, &blk)
        messages << [:debug, msgs, blk]
      end

      def log_exception(level, e, backtrace_level=level)
        messages << [:log_exception, [level, e, backtrace_level]]
      end

      def dump(logger)
        messages.each do |(method, args, blk)|
          logger.send(method, *args, &blk)
        end
        messages.clear
      end
    end
  end
end
