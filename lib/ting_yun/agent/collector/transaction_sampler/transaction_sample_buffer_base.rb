# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

module TingYun
  module Agent
    module Collector
      class TransactionSampler
        class TransactionSampleBufferBase

          SINGLE_BUFFER_MAX = 1000
          NO_SAMPLES = [].freeze

          def initialize
            @samples = []
          end

          #If a buffer needs to modify, override this method.
          def allow_sample?(sample)
            true
          end

          #If a buffer needs to modify, override this method.
          def enabled?
            true
          end

          def reset!
            @samples = []
          end

          def harvest_samples
            @samples
          ensure
            reset!
          end

          def store(sample)
            return unless enabled?
            if allow_sample?(sample)
              add_sample(sample)
              truncate_samples_if_needed
            end
          end

          def store_previous(previous_samples)
            return unless enabled?
            previous_samples.each do |sample|
              add_sample(sample) if allow_sample?(sample)
            end
            truncate_samples_if_needed
          end

          def truncate_samples_if_needed
            truncate_samples if full?
          end

          def full?
            @samples.length >= max_capacity
          end


          # Capacity is the desired number of samples a buffer will hold. This
          # can be user dictated via config if a feature wants.
          #
          # This value will be forcibly capped by the max_capacity
          def capacity
            raise NotImplementedError.new("TransactionSampleBufferBase subclasses must provide a capacity override")
          end

          def max_capacity
            capacity > SINGLE_BUFFER_MAX ? SINGLE_BUFFER_MAX : capacity
          end

          # Our default truncation strategy is to keep max_capacity
          # worth of the longest samples. Override this method for alternate
          # behavior.
          def truncate_samples
            @samples.sort!{|a,b| a.duration <=> b.duration}
            @samples.slice!(0..-(max_capacity + 1))
          end


          private

          # If a buffer needs to modify an added sample, override this method.
          # Bounds checking, allowing samples and truncation belongs elsewhere.
          def add_sample(sample)
            @samples << sample
          end

        end
      end
    end
  end
end

