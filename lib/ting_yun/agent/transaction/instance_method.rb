# encoding: utf-8
require 'ting_yun/support/quantile_p2'
module TingYun
  module Agent
    class Transaction
      module InstanceMethod

        def ignore!
          @ignore_this_transaction = true
        end

        def ignore?
          @ignore_this_transaction
        end

        def create_nested_frame(state, category, options)
          @has_children = true
          frame_stack.push TingYun::Agent::MethodTracerHelpers.trace_execution_scoped_header(state, Time.now.to_f)
          name_last_frame(options[:transaction_name])

          set_default_transaction_name(options[:transaction_name], category)
        end


        def set_default_transaction_name(name, category)
          if @frozen_name
            TingYun::Agent.logger.warn("Attempted to rename transaction to '#{name}' after transaction name was already frozen as '#{@frozen_name}'.")
            return
          end
          if influences_transaction_name?(category)
            @default_name = name
            @category = category if category
          end
        end

        def make_transaction_name(name, category=nil)
          namer = TingYun::Instrumentation::Support::TransactionNamer
          "#{namer.prefix_for_category(self, category)}#{name}"
        end

        def name_last_frame(name)
          frame_stack.last.name = name
        end


        def best_name
          @frozen_name || @default_name || ::TingYun::Agent::UNKNOWN_METRIC
        end


        def influences_transaction_name?(category)
          !category || frame_stack.size == 1 || similar_category?(category)
        end

        WEB_TRANSACTION_CATEGORIES = [:controller, :uri, :rack, :sinatra, :grape, :middleware, :thrift, :action_cable, :message].freeze

        def web_category?(category)
          WEB_TRANSACTION_CATEGORIES.include?(category)
        end

        def similar_category?(category)
          web_category?(@category) == web_category?(category)
        end


        def needs_middleware_summary_metrics?(name)
          name.start_with?(MIDDLEWARE_PREFIX)
        end

        alias_method :ignore, :needs_middleware_summary_metrics?

        def record_summary_metrics(state, outermost_node_name,end_time)
          unless @frozen_name == outermost_node_name
            time = (end_time.to_f - start_time.to_f) * 1000
            @metrics.record_unscoped(@frozen_name, time)
            if @frozen_name.start_with?('WebAction')
              state.current_transaction.base_quantile_hash[@frozen_name] = time
            end
          end
        end

        def assign_agent_attributes

          @attributes.add_agent_attribute(:threadName,  "pid-#{$$}");

          if @request_attributes
            @request_attributes.assign_agent_attributes @attributes
          end

          @attributes.add_agent_attribute(:tx_id,  @guid);
          @attributes.add_agent_attribute(:metric_name,  best_name);

        end


        # This transaction-local hash may be used as temprory storage by
        # instrumentation that needs to pass data from one instrumentation point
        # to another.
        #
        # For example, if both A and B are instrumented, and A calls B
        # but some piece of state needed by the instrumentation at B is only
        # available at A, the instrumentation at A may write into the hash, call
        # through, and then remove the key afterwards, allowing the
        # instrumentation at B to read the value in between.
        #
        # Keys should be symbols, and care should be taken to not generate key
        # names dynamically, and to ensure that keys are removed upon return from
        # the method that creates them.
        #
        def instrumentation_state
          @instrumentation_state ||= {}
        end

        def with_database_metric_name(model, method, product=nil)
          previous = self.instrumentation_state[:datastore_override]
          model_name = case model
                         when Class
                           model.name
                         when String
                           model
                         else
                           model.to_s
                       end
          @instrumentation_state[:datastore_override] = [method, model_name, product]
          yield
        ensure
          @instrumentation_state[:datastore_override] = previous
        end

        def freeze_name_and_execute
          unless @frozen_name
            @frozen_name = best_name
          end

          yield if block_given?
        end



        HEX_DIGITS = (0..15).map{|i| i.to_s(16)}
        GUID_LENGTH = 16

        # generate a random 64 bit uuid
        private
        def generate_guid
          guid = ''
          GUID_LENGTH.times do
            guid << HEX_DIGITS[rand(16)]
          end
          guid
        end
      end
    end
  end
end
