# encoding: utf-8
# This file is distributed under Ting Yun's license terms.



module TingYun
  module Metrics
    class MetricData

      # nil, or a TingYun::Metrics::MetricSpec object if we have no cached ID
      attr_reader :metric_spec
      # nil or a cached integer ID for the metric from the collector.
      attr_accessor :metric_id
      # the actual statistics object
      attr_accessor :stats
      attr_reader :quantile

      def initialize(metric_spec, stats, metric_id, quantile = [])
        @metric_spec = metric_spec
        @stats = stats
        @metric_id = metric_id
        @quantile = quantile
      end

      def eql?(o)
        (metric_spec.eql? o.metric_spec) && (stats.eql? o.stats)
      end

      def hash
        metric_spec.hash ^ stats.hash
      end

      # Serialize with all attributes, but if the metric id is not nil, then don't send the metric spec
      def to_json(*a)
        %Q[{"metric_spec":#{metric_id ? 'null' : metric_spec.to_json},"stats":{"total_exclusive_time":#{stats.total_exclusive_time},"min_call_time":#{stats.min_call_time},"call_count":#{stats.call_count},"sum_of_squares":#{stats.sum_of_squares},"total_call_time":#{stats.total_call_time},"max_call_time":#{stats.max_call_time}},"metric_id":#{metric_id ? metric_id : 'null'}}]
      end

      def to_s
        if metric_spec
          "#{metric_spec.name}(#{metric_spec.scope}): #{stats}"
        else
          "#{metric_id}: #{stats}"
        end
      end

      def inspect
        "#<MetricData metric_spec:#{metric_spec.inspect}, stats:#{stats.inspect}, metric_id:#{metric_id.inspect}>"
      end


      def to_collector_array(encoder=nil)
        stat_key = metric_id || to_hash
        if quantile.empty?
          [stat_key, metrics(stat_key)]
        else
          [stat_key, metrics(stat_key), quantile]
        end
      end

      def to_hash
        metric_spec.to_hash
      end

      def metrics(stat_key)
        stats.metrics(stat_key)
      end

    end
  end
end