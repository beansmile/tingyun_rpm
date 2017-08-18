# encoding: utf-8


# A Hash-like class for storing perfMetrics data.
#
# Internally, metrics are split into unscoped and scoped collections.
#
# Unscoped metrics are stored in a Hash, keyed by Strings representing the name
# of the metrics.
#
# Scoped metrics are stored in a Hash where the keys are TingYun::Metrics::MetricSpec
# objects (effectively <name, scope> tuples).
#
# Values in both hashes are TingYun::Metrics::Stats objects.
#
# Missing keys will be automatically created as empty TingYun::Metrics::Stats
# instances, so use has_key? explicitly to check for key existence.
#
# Note that instances of this class are intended to be append-only with respect
# to new metrics. That is, you should not attempt to *remove* an entry after it
# has been added, only update it (create a new instance if you need to start
# over with a blank slate).
#
# This class makes no provisions for safe usage from multiple threads, such
# measures should be externally provided.

require 'ting_yun/metrics/stats'
require 'ting_yun/metrics/metric_spec'
require 'ting_yun/support/exception'

module TingYun
  module Agent
    module Collector
      class StatsHash

        attr_accessor :started_at, :harvested_at

        def initialize(started_at=Time.now)
          @started_at = started_at.to_f
          @scoped = Hash.new { |h, k| h[k] = TingYun::Metrics::Stats.new }
          @unscoped = Hash.new { |h, k| h[k] = TingYun::Metrics::Stats.new }
        end

        def marshal_dump
          [@started_at, Hash[@scoped], Hash[@unscoped]]
        end

        def marshal_load(data)
          @started_at = data.shift
          @scoped = Hash.new { |h, k| h[k] = TingYun::Metrics::Stats.new }
          @unscoped = Hash.new { |h, k| h[k] = TingYun::Metrics::Stats.new }
          @scoped.merge!(data.shift)
          @unscoped.merge!(data.shift)
        end

        def ==(other)
          self.to_h == other.to_h
        end

        def to_h
          hash = {}
          @scoped.each { |k, v| hash[k] = v }
          @unscoped.each { |k, v| hash[TingYun::Metrics::MetricSpec.new(k)] = v }
          hash
        end

        def [](key)
          case key
            when String
              @unscoped[key]
            when TingYun::Metrics::MetricSpec
              if key.scope.empty?
                @unscoped[key.name]
              else
                @scoped[key]
              end
          end
        end

        def each
          @scoped.each do |k, v|
            yield k, v
          end
          @unscoped.each do |k, v|
            spec = TingYun::Metrics::MetricSpec.new(k)
            yield spec, v
          end
        end

        def empty?
          @unscoped.empty? && @scoped.empty?
        end

        def size
          @unscoped.size + @scoped.size
        end

        def merge!(other)
          @started_at = other.started_at if other.started_at < @started_at

          other.each do |spec, val|
            if spec.scope.empty?
              merge_or_insert(@unscoped, spec.name, val)
            else
              merge_or_insert(@scoped, spec, val)
            end
          end
          self
        end

        class StatsHashLookupError < TingYun::Support::Exception::InternalAgentError
          def initialize(original_error, metric_spec)
            super("Lookup error in StatsHash: #{original_error.class}: #{original_error.message}. Falling back adding #{metric_spec.inspect}")
          end
        end

        def record(metric_specs, value=nil, aux=nil, &blk)
          Array(metric_specs).each do |metric_spec|
            if metric_spec.scope.empty?
              key = metric_spec.name
              hash = @unscoped
            else
              key = metric_spec
              hash = @scoped
            end

            begin
              stats = hash[key]
            rescue NoMethodError => e
              stats = handle_stats_lookup_error(key, hash, e)
            end

            stats.record(value, aux, &blk)
          end
        end

        def merge_transaction_metrics!(txn_metrics, scope)

          txn_metrics.each_unscoped do |name, stats|
            merge_or_insert(@unscoped, name, stats)
          end
          txn_metrics.each_scoped do |name, stats|
            spec = TingYun::Metrics::MetricSpec.new(name, scope)
            merge_or_insert(@scoped, spec, stats)
          end
        end

        def merge_or_insert(target, name, stats)
          if target.has_key?(name)
            target[name].merge!(stats)
          else
            target[name] = stats
          end
        end

        def handle_stats_lookup_error(key, hash, error)
          # This only happen in the case of a corrupted default_proc
          # Side-step it manually, notice the issue, and carry on....
          ::TingYun::Agent.instance.error_collector. \
          notice_agent_error(StatsHashLookupError.new(error, key))
          stats = TingYun::Metrics::Stats.new
          hash[key] = stats
          # Try to restore the default_proc so we won't continually trip the error
          if hash.respond_to?(:default_proc=)
            hash.default_proc = Proc.new { |h, k| h[k] = TingYun::Metrics::Stats.new }
          end
          stats
        end
      end
    end
  end
end
