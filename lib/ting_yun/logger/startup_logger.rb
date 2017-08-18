# encoding: utf-8
require 'ting_yun/logger/memory_logger'
require 'singleton'

module TingYun
  module Logger
    # In an effort to not lose messages during startup, we trap them in memory
    # The real logger will then dump its contents out when it arrives.
    class StartupLogger < MemoryLogger
      include Singleton
    end
  end
end