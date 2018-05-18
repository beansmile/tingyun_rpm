# encoding: utf-8
require 'ting_yun/support/exception'
require 'ting_yun/agent/collector/stats_engine'
require 'ting_yun/agent/collector/error_collector'

require 'ting_yun/agent/collector/transaction_sampler'

require 'ting_yun/agent/collector/sql_sampler'


module TingYun
  module Agent
    module InstanceMethods
      module ContainerDataManager


        attr_reader :stats_engine, :error_collector, :transaction_sampler, :sql_sampler


        def drop_buffered_data
          @stats_engine.reset!
          @transaction_sampler.reset!
          @sql_sampler.reset!
          @error_collector.reset!
        end

        def reset_objects_with_locks
          init_containers
        end


        def init_containers
          @stats_engine = TingYun::Agent::Collector::StatsEngine.new
          @error_collector = TingYun::Agent::Collector::ErrorCollector.new
          @transaction_sampler = TingYun::Agent::Collector::TransactionSampler.new
          @sql_sampler = TingYun::Agent::Collector::SqlSampler.new
        end

        def container_for_endpoint(endpoint)
          case endpoint
            when :metric_data then
              @stats_engine
            # type code here
          end
        end

        def transmit_data
          ::TingYun::Agent.logger.debug('Sending data to Ting Yun Service')

          @events.notify(:middleware_harvest)
          @service.session do # use http keep-alive
            harvest_and_send_errors
            harvest_and_send_external_errors
            harvest_and_send_exceptions
            harvest_and_send_timeslice_data
            harvest_and_send_transaction_traces
            harvest_and_send_slowest_sql
          end
        end

        def harvest_and_send_timeslice_data
          harvest_and_send_from_container(@stats_engine, :metric_data)
        end

        def harvest_and_send_errors
          harvest_and_send_from_container(@error_collector.error_trace_array, :error_data)
        end

        def harvest_and_send_exceptions
          harvest_and_send_from_container(@error_collector.exception_error_array, :exception_data)
        end


        def harvest_and_send_external_errors
          harvest_and_send_from_container(@error_collector.external_error_array, :external_error_data)
        end


        def harvest_and_send_transaction_traces
          harvest_and_send_from_container(@transaction_sampler, :action_trace_data)

        end

        def harvest_and_send_slowest_sql
          harvest_and_send_from_container(@sql_sampler, :sql_trace)

        end

        # Harvests data from the given container, sends it to the named endpoint
        # on the service, and automatically merges back in upon a recoverable
        # failure.
        #
        # The given container should respond to:
        #
        #  #harvest!
        #    returns an enumerable collection of data items to be sent to the
        #    collector.
        #
        #  #reset!
        #    drop any stored data and reset to a clean state.
        #
        #  #merge!(items)
        #    merge the given items back into the internal buffer of the
        #    container, so that they may be harvested again later.
        #
        def harvest_and_send_from_container(container, endpoint)
          items = harvest_from_container(container, endpoint)
          send_data_to_endpoint(endpoint, items, container)
        end

        def harvest_from_container(container, endpoint)
          items =[]
          begin
             if TingYun::Agent.config[:'enabled']
               items = container.harvest!
             else
               container.reset!
             end
          rescue => e
            TingYun::Agent.logger.error("Failed to harvest #{endpoint} data, resetting. Error: ", e)
            container.reset!
          end
          items
        end

        def send_data_to_endpoint(endpoint, items, container)
          TingYun::Agent.logger.info("Sending #{items.size} items to #{endpoint}")
          begin
            if container.respond_to?(:harvest_base_quantile_hash!)
              @service.send(endpoint, items, container.harvest_base_quantile_hash!)
            else
              @service.send(endpoint, items)
            end
          rescue => e
            TingYun::Agent.logger.info("Unable to send #{endpoint} data, will try again later. Error: ", e)
            # container.merge!(items)
            raise
          ensure
            items = nil #  to GC
          end


        end

      end

    end
  end
end
