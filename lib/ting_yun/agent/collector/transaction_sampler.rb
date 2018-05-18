# encoding: utf-8

require 'ting_yun/agent/transaction/transaction_sample_builder'
require 'ting_yun/agent/collector/transaction_sampler/slowest_sample_buffer'
require 'ting_yun/agent/collector/transaction_sampler/class_method'
require 'ting_yun/agent/transaction/transaction_state'


module TingYun
  module Agent
    module Collector
      class TransactionSampler

        extend TingYun::Agent::Collector::TransactionSampler::ClassMethod

        attr_accessor :last_sample


        def initialize
          @lock = Mutex.new
          @sample_buffers = []
          @sample_buffers << TingYun::Agent::Collector::TransactionSampler::SlowestSampleBuffer.new
        end

        def harvest!
          return [] unless TingYun::Agent.config[:'nbs.action_tracer.enabled']

          samples = @lock.synchronize do
            @last_sample = nil
            harvest_from_sample_buffers
          end

          prepare_samples(samples)
        end
        def harvest_from_sample_buffers
          result = []
          @sample_buffers.each { |buffer| result.concat(buffer.harvest_samples) }
          result.uniq
        end
        def prepare_samples(samples)
          samples.select do |sample|
            begin
              sample.prepare_to_send!
            rescue => e
              TingYun::Agent.logger.error('Failed to prepare transaction trace. Error: ', e)
              false
            else
              true
            end
          end
        end
        def merge!(previous)
          @lock.synchronize do
            @sample_buffers.each do |buffer|
              buffer.store_previous(previous)
            end
          end
        end
        def reset!
          @lock.synchronize do
            @sample_buffers.each { |sample| sample.reset! }
          end
        end

        def on_finishing_transaction(state, txn, time=Time.now.to_f, exceptions)

          last_builder = state.transaction_sample_builder
          return unless last_builder && TingYun::Agent.config[:'nbs.action_tracer.enabled']

          last_builder.finish_trace(time)

          final_trace = last_builder.trace
          final_trace.attributes = txn.attributes
          final_trace.array_size = exceptions.errors_and_exceptions
          final_trace.add_errors(exceptions.errors.keys)


          @lock.synchronize do
            @last_sample = final_trace

            store_sample(@last_sample)
            @last_sample
          end
        end
        def store_sample(sample)
          @sample_buffers.each do |sample_buffer|
            sample_buffer.store(sample)
          end
        end


      end
    end
  end
end
