# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require 'ting_yun/agent/collector/transaction_sampler/transaction_sample_buffer_base'
module TingYun
  module Agent
    module Collector
      class TransactionSampler
        class SlowestSampleBuffer < TransactionSampleBufferBase

          CAPACITY = 500

          def capacity
            CAPACITY
          end

          def allow_sample?(sample)
            sample.threshold && sample.duration >= sample.threshold
          end

        end
      end
    end
  end
end
