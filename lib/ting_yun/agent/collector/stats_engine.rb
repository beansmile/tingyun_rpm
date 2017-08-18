# encoding: utf-8

require 'ting_yun/agent/collector/stats_engine/stats_hash'
require 'ting_yun/agent/collector/stats_engine/metric_stats'
require 'ting_yun/agent/collector/stats_engine/base_quantile_hash'

module TingYun
  module Agent
    module Collector
      # This class handles all the statistics gathering for the agent
      class StatsEngine

        include MetricStats

        attr_reader :base_quantile_hash

        def initialize
          @stats_lock = Mutex.new
          @stats_hash = StatsHash.new
          @base_quantile_hash = BaseQuantileHash.new
        end

        # All access to the @stats_hash ivar should be funnelled through this
        # method to ensure thread-safety.
        def with_stats_lock
          @stats_lock.synchronize { yield }
        end

        def record_base_quantile(hash)
          with_stats_lock do
            @base_quantile_hash.merge!(hash)
          end
        end
      end
    end
  end
end
