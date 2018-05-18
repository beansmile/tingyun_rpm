# encoding: utf-8
require 'ting_yun/support/helper'
module TingYun
  module Agent

    class Transaction
      class Apdex
        APDEX_TXN_METRIC_PREFIX = 'Apdex/'.freeze

        attr_accessor :apdex_start, :transaction_start_time

        def initialize(start, transaction_start)
          @apdex_start = (start || transaction_start).to_f
          @transaction_start_time = transaction_start
        end

        def record_apdex(metric_name, end_time, failed)
          total_duration = TingYun::Helper.time_to_millis(end_time - apdex_start)
          if TingYun::Agent::Transaction.recording_web_transaction?
            record_apdex_metrics(APDEX_TXN_METRIC_PREFIX, total_duration, TingYun::Agent.config[:apdex_t], metric_name, failed)
          end
        end

        def record_apdex_metrics(transaction_prefix, total_duration, current_apdex_t, metric_name, failed)
          return unless current_apdex_t
          return unless metric_name.start_with?(CONTROLLER_PREFIX)

          apdex_bucket_global = apdex_bucket(total_duration, failed, current_apdex_t)
          txn_apdex_metric = metric_name.sub(/^[^\/]+\//, transaction_prefix)
          ::TingYun::Agent::Transaction.metrics.record_unscoped(txn_apdex_metric, apdex_bucket_global, current_apdex_t)
        end


        def apdex_bucket(duration, failed, apdex_t)
          case
            when failed
              :apdex_f
            when duration <= apdex_t
              :apdex_s
            when duration <= 4 * apdex_t
              :apdex_t
            else
              :apdex_f
          end
        end

        def queue_time
          @transaction_start_time - @apdex_start
        end
      end
    end
  end
end
