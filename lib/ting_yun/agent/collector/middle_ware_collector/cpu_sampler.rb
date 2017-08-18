# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/agent/collector/middle_ware_collector/sampler'
require 'ting_yun/support/system_info'

module TingYun
  module Agent
    module Collector
      class CpuSampler < ::TingYun::Agent::Collector::Sampler
        attr_reader :last_time

        named :cpu

        def initialize
          @last_time = nil
          @processor_count = TingYun::Support::SystemInfo.num_logical_processors
          if @processor_count.nil?
            TingYun::Agent.logger.warn("Failed to determine processor count, assuming 1")
            @processor_count = 1
          end
          poll
        end

        def record_user_util(value)
          TingYun::Agent.record_metric("CPU/NULL/UserUtilization", value)
        end

        def record_system_util(value)
          TingYun::Agent.record_metric("CPU/System/Utilization", value)
        end

        def record_usertime(value)
          TingYun::Agent.record_metric("CPU/NULL/UserTime", value)
        end

        def record_systemtime(value)
          TingYun::Agent.record_metric("CPU/System Time", value)
        end

        def poll
          now = Time.now
          t = Process.times
          if @last_time
            elapsed = now - @last_time
            return if elapsed < 1 # Causing some kind of math underflow

            usertime = t.utime - @last_utime

            if usertime >= 0
              record_usertime(usertime)
              record_user_util((usertime * 100) / (elapsed * @processor_count))
            end
          end
          @last_utime = t.utime
          @last_stime = t.stime
          @last_time = now
        end
      end
    end
  end
end

