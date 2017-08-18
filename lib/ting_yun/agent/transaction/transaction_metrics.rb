# encoding: utf-8
require 'ting_yun/metrics/stats'

module TingYun
  module Agent
    class TransactionMetrics
      DEFAULT_PROC = Proc.new { |hash, name| hash[name] = TingYun::Metrics::Stats.new }


      def initialize
        @unscoped = Hash.new(&DEFAULT_PROC)
        @scoped   = Hash.new(&DEFAULT_PROC)
      end

      def record_scoped(names, value=nil, aux=nil, &blk)
        _record_metrics(names, value, aux, @scoped, &blk)
      end

      def record_unscoped(names, value=nil, aux=nil, &blk)
        _record_metrics(names, value, aux, @unscoped, &blk)
      end

      def has_key?(key)
        @unscoped.has_key?(key)
      end

      def [](key)
        @unscoped[key]
      end

      def each_unscoped
        @unscoped.each { |name, stats| yield name, stats }
      end

      def each_scoped
        @scoped.each { |name, stats| yield name, stats }
      end

      def _record_metrics(names, value, aux, target, &blk)
        # This looks dumb, but we're avoiding an extra Array allocation.
        case names
          when Array
            names.each do |name|
              target[name].record(value, aux, &blk)
            end
          else
            target[names].record(value, aux, &blk)
        end
      end
    end
  end
end
