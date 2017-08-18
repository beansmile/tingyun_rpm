# encoding: utf-8

require 'forwardable'

module TingYun
  module Agent
    class TransactionTimings

      class Timings <  Struct.new :sql_duration, :external_duration, :rds_duration, :mc_duration, :mon_duration; end

      def initialize(queue_time_in_seconds, start_time_in_seconds)
        @queue_time_in_seconds = clamp_to_positive(queue_time_in_seconds.to_f)
        @start_time_in_seconds = clamp_to_positive(start_time_in_seconds.to_f)

        @timings = TingYun::Agent::TransactionTimings::Timings.new(0.0, 0.0, 0.0, 0.0, 0.0)
      end


      attr_reader :start_time_in_seconds, :queue_time_in_seconds, :timings

      extend Forwardable

      def_delegators :@timings, :sql_duration, :sql_duration= ,
                     :external_duration, :external_duration=,
                     :rds_duration, :rds_duration=,
                     :mc_duration, :mc_duration=,
                     :mon_duration, :mon_duration=


      def start_time_as_time
        Time.at(@start_time_in_seconds)
      end

      def start_time_in_millis
        convert_to_milliseconds(@start_time_in_seconds)
      end

      def queue_time_in_millis
        convert_to_milliseconds(queue_time_in_seconds)
      end

      def app_time_in_millis
        convert_to_milliseconds(app_time_in_seconds)
      end

      def app_time_in_seconds
        Time.now.to_f - @start_time_in_seconds
      end

      def app_execute_duration
        app_time_in_millis - queue_time_in_millis - sql_duration - external_duration - rds_duration - mon_duration - mc_duration
      end

      # Helpers

      def slow_action_tracer?
        return app_time_in_millis > TingYun::Agent.config[:'nbs.action_tracer.action_threshold']
      end

      def convert_to_milliseconds(value_in_seconds)
        clamp_to_positive((value_in_seconds.to_f * 1000.0).round)
      end

      def clamp_to_positive(value)
        return 0.0 if value < 0.0
        value
      end

    end
  end
end