# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/support/coerce'

module TingYun
  module Metrics
    class Stats
      attr_accessor :call_count
      attr_accessor :min_call_time
      attr_accessor :max_call_time
      attr_accessor :total_call_time
      attr_accessor :total_exclusive_time
      attr_accessor :sum_of_squares


      def self.create_from_hash(hash_value)
        stats = Stats.new
        stats.call_count           = hash_value[:count] if hash_value[:count]
        stats.total_call_time      = hash_value[:total] if hash_value[:total]
        stats.total_exclusive_time = hash_value[:total] if hash_value[:total]
        stats.min_call_time        = hash_value[:min] if hash_value[:min]
        stats.max_call_time        = hash_value[:max] if hash_value[:max]
        stats.sum_of_squares       = hash_value[:sum_of_squares] if hash_value[:sum_of_squares]
        stats
      end


      def initialize
        reset
      end

      def reset
        @call_count = 0
        @total_call_time = 0.0
        @total_exclusive_time = 0.0
        @min_call_time = 0.0
        @max_call_time = 0.0
        @sum_of_squares = 0.0
      end

      alias_method :apdex_s, :call_count
      alias_method :apdex_t, :total_call_time
      alias_method :apdex_f, :total_exclusive_time


      def is_reset?
        call_count == 0 && total_call_time == 0.0 && total_exclusive_time == 0.0
      end

      #self不变
      def merge(other_stats)
        stats = self.clone
        stats.merge!(other_stats)
      end

      #self变化
      def merge!(other)
        @min_call_time = other.min_call_time if min_time_less?(other)
        @max_call_time = other.max_call_time if max_time?(other)
        @total_call_time += other.total_call_time
        @total_exclusive_time += other.total_exclusive_time
        @sum_of_squares += other.sum_of_squares
        @call_count += other.call_count
        self
      end

      def to_s
        "[#{'%2i' % call_count.to_i} calls #{'%.4f' % total_call_time.to_f}s / #{'%.4f' % total_exclusive_time.to_f}s ex]"
      end

      def to_json(*_)
        {
            'call_count' => call_count.to_i,
            'min_call_time' => min_call_time.to_f,
            'max_call_time' => max_call_time.to_f,
            'total_call_time' => total_call_time.to_f,
            'total_exclusive_time' => total_exclusive_time.to_f,
            'sum_of_squares' => sum_of_squares.to_f
        }.to_json(*_)
      end





      def record(value=nil, aux=nil, &blk)
        if blk
          yield self
        else
          case value
            when Numeric
              aux ||= value
              self.record_data_point(value, aux)
            when :apdex_s, :apdex_t, :apdex_f
              self.record_apdex(value, aux)
            when TingYun::Metrics::Stats
              self.merge!(value)
          end
        end
      end

      def record_apdex(bucket, apdex_t)
        case bucket
          when :apdex_s then @call_count += 1
          when :apdex_t then @total_call_time += 1
          when :apdex_f then @total_exclusive_time += 1
        end
        if apdex_t
          @max_call_time = apdex_t
        else
          ::TingYun::Agent.logger.warn("Attempted to set apdex_t to #{apdex_t.inspect}, backtrace = #{caller.join("\n")}")
        end
      end


      # record a single data point into the statistical gatherer.  The gatherer
      # will aggregate all data points collected over a specified period and upload
      # its data to the TingYun server
      def record_data_point(value, exclusive_time = value)
        @call_count += 1
        @total_call_time += value
        @min_call_time = exclusive_time if exclusive_time < @min_call_time || @call_count == 1
        @max_call_time = exclusive_time if exclusive_time > @max_call_time
        @total_exclusive_time += exclusive_time

        @sum_of_squares += (exclusive_time * exclusive_time)
        self
      end

      alias trace_call record_data_point

      # increments the call_count by one
      def increment_count(value = 1)
        @call_count += value
      end

      def ==(other)
        other.class == self.class &&
            (
            @min_call_time == other.min_call_time &&
                @max_call_time == other.max_call_time &&
                @total_call_time == other.total_call_time &&
                @total_exclusive_time == other.total_exclusive_time &&
                @sum_of_squares == other.sum_of_squares &&
                @call_count == other.call_count
            )
      end

      include TingYun::Support::Coerce

      def metrics(stat_key)
        metrics = []

        metrics << int(call_count, stat_key)
        if max_call_time != 0.0 #apedx
          metrics << float(total_call_time, stat_key)
          metrics << float(total_exclusive_time, stat_key)
          metrics << float(max_call_time, stat_key)
        end

        if min_call_time !=0.0 #
          metrics << float(min_call_time, stat_key)
          metrics << float(sum_of_squares, stat_key)
        end

        metrics
      end

      protected

      def min_time_less?(other)
        (other.min_call_time < min_call_time && other.call_count > 0) || call_count == 0
      end

      def max_time?(other)
        other.max_call_time > max_call_time
      end

    end
  end
end