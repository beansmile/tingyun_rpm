# encoding: utf-8

require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/instrumentation/support/transaction_namer'
require 'ting_yun/agent/transaction'
require 'ting_yun/agent'
require 'ting_yun/support/helper'

module TingYun
  module Instrumentation
    module Support

      # This module can also be used to capture performance information for
      # background tasks and other non-web transactions, including
      # detailed transaction traces and traced errors.
      module ControllerInstrumentation

        extend self

        def self.included klass
          klass.extend ClassMethods
        end

        def self.extended klass
          klass.extend ClassMethods
        end


        module ClassMethods
          # Add transaction tracing to the given method.  This will treat
          # the given method as a main entrypoint for instrumentation, just
          # like controller actions are treated by default.  Useful especially
          # for background tasks.
          # Example for background job:
          #   class Job
          #     include TingYun::Instrumentation::Support::ControllerInstrumentation
          #     def run(task)
          #        ...
          #     end
          #     # Instrument run so tasks show up under task.name.  Note single
          #     # quoting to defer eval to runtime.
          #     add_transaction_tracer :run, :name => '#{args[0].name}'
          #   end
          #
          # Here's an example of a controller that uses a dispatcher
          # action to invoke operations which you want treated as top
          # level actions, so they aren't all lumped into the invoker
          # action.
          #
          #   MyController < ActionController::Base
          #     include TingYun::Instrumentation::Support::ControllerInstrumentation
          #     # dispatch the given op to the method given by the service parameter.
          #     def invoke_operation
          #       op = params['operation']
          #       send op
          #     end
          #     # Ignore the invoker to avoid double counting
          #     tingyun_ignore :only => 'invoke_operation'
          #     # Instrument the operations:
          #     add_transaction_tracer :print
          #     add_transaction_tracer :show
          #     add_transaction_tracer :forward
          #   end
          #
          # Here's an example of how to pass contextual information into the transaction
          # so it will appear in transaction traces:
          #
          #   class Job
          #    include TingYun::Instrumentation::Support::ControllerInstrumentation
          #     def process(account)
          #        ...
          #     end
          #     # Include the account name in the transaction details.  Note the single
          #     # quotes to defer eval until call time.
          #     add_transaction_tracer :process, :params => '{ :account_name => args[0].name }'
          #   end
          #``
          #
          # @api public
          #
          def add_transaction_tracer(method, options={})
            options[:name] ||= method.to_s
            argument_list = generate_argument_list(options)
            traced_method, punctuation = parse_punctuation(method)
            with_method_name, without_method_name = build_method_names(traced_method, punctuation)

            if already_added_transaction_tracer?(self, with_method_name)
              ::TingYun::Agent.logger.warn("Transaction tracer already in place for class = #{self.name}, method = #{method.to_s}, skipping")
              return
            end

            class_eval <<-EOC
            def #{with_method_name}(*args,&block)
              perform_action_with_tingyun_trace(#{argument_list.join(',')}) do
                #{without_method_name}(*args, &block)
              end
            end
            EOC

            visibility = TingYun::Helper.instance_method_visibility self, method

            alias_method without_method_name, method.to_s
            alias_method method.to_s, with_method_name
            send visibility, method
            send visibility, with_method_name
            ::TingYun::Agent.logger.debug("Traced transaction: class = #{self.name}, method = #{method.to_s}, options = #{options.inspect}")
          end

          def already_added_transaction_tracer?(target, with_method_name)
            if TingYun::Helper.instance_methods_include?(target, with_method_name)
              true
            else
              false
            end
          end

          def parse_punctuation(method)
            [method.to_s.sub(/([?!=])$/, ''), $1]
          end

          def build_method_names(traced_method, punctuation)
            [ "#{traced_method.to_s}_with_tingyun_transaction_trace#{punctuation}",
              "#{traced_method.to_s}_without_tingyun_transaction_trace#{punctuation}" ]
          end

          def generate_argument_list(options)
            options.map do |key, value|
              value = if value.is_a?(Symbol)
                        value.inspect
                      elsif key == :params
                        value.to_s
                      else
                        %Q["#{value.to_s}"]
                      end

              %Q[:#{key} => #{value}]
            end
          end



        end



        # Yield to the given block with TingYun tracing.  Used by
        # default instrumentation on controller actions in Rails and Merb.
        # But it can also be used in custom instrumentation of controller
        # methods and background tasks.

        # This is the method invoked by instrumentation added by the
        # <tt>ClassMethods#add_transaction_tracer</tt>.

        # Below is a controller with an +invoke_operation+ action which
        # dispatches to more specific operation methods based on a
        # parameter (very dangerous, btw!).  With this instrumentation,
        # the +invoke_operation+ action is ignored but the operation
        # methods show up in TingYun as if they were first class controller
        # actions
        #
        #   MyController < ActionController::Base
        #     include TingYun::Instrumentation::Support::ControllerInstrumentation
        #     # dispatch the given op to the method given by the service parameter.
        #     def invoke_operation
        #       op = params['operation']
        #       perform_action_with_tingyun_trace(:name => op) do
        #         send op, params['message']
        #       end
        #     end
        #     # Ignore the invoker to avoid double counting
        #     tingyun_ignore :only => 'invoke_operation'
        #   end
        #
        # When invoking this method explicitly as in the example above, pass in a
        # block to measure with some combination of options:
        #
        # * <tt>:category => :controller</tt> indicates that this is a
        #   controller action and will appear with all the other actions.  This
        #   is the default.
        # * <tt>:category => :task</tt> indicates that this is a
        #   background task and will show up in Ting Yun with other background
        #   tasks instead of in the controllers list
        # * <tt>:category => :middleware</tt> if you are instrumenting a rack
        #   middleware call.  The <tt>:name</tt> is optional, useful if you
        #   have more than one potential transaction in the #call.
        # * <tt>:category => :uri</tt> indicates that this is a
        #   web transaction whose name is a normalized URI, where  'normalized'
        #   means the URI does not have any elements with data in them such
        #   as in many REST URIs.
        # * <tt>:name => action_name</tt> is used to specify the action
        #   name used as part of the metric name
        # * <tt>:params => {...}</tt> to provide information about the context
        #   of the call, used in transaction trace display, for example:
        #   <tt>:params => { :account => @account.name, :file => file.name }</tt>
        #   These are treated similarly to request parameters in web transactions.
        #
        # Seldomly used options:
        #
        # * <tt>:class_name => aClass.name</tt> is used to override the name
        #   of the class when used inside the metric name.  Default is the
        #   current class.
        # * <tt>:path => metric_path</tt> is *deprecated* in the public API.  It
        #   allows you to set the entire metric after the category part.  Overrides
        #   all the other options.
        # * <tt>:request => Rack::Request#new(env)</tt> is used to pass in a
        #   request object that may respond to path and referer.
        #
        # @api public
        #
        NR_DEFAULT_OPTIONS    = {}.freeze          unless defined?(NR_DEFAULT_OPTIONS   )

        def perform_action_with_tingyun_trace (*args, &block)

          state = TingYun::Agent::TransactionState.tl_get

          skip_tracing = !state.execution_traced?

          if skip_tracing
            state.current_transaction.ignore! if state.current_transaction
            TingYun::Agent.disable_all_tracing { return yield }
          end
          trace_options = args.last.is_a?(Hash) ? args.last : NR_DEFAULT_OPTIONS
          category = trace_options[:category] || :controller
          txn_options = create_transaction_options(trace_options, category)

          begin
            TingYun::Agent::Transaction.start(state, category, txn_options)
            begin
              yield
            rescue => e
              ::TingYun::Agent.notice_error(e)
              raise
            end
          ensure
            TingYun::Agent::Transaction.stop(state)
          end
        end

        private

        def create_transaction_options(trace_options, category)
          txn_options = {}

          txn_options[:request] ||= request if respond_to?(:request)
          txn_options[:request] ||= trace_options[:request] if trace_options[:request]
          txn_options[:filtered_params] = trace_options[:params]
          txn_options[:transaction_name] = TingYun::Instrumentation::Support::TransactionNamer.name_for(nil, self, category, trace_options)
          txn_options[:apdex_start_time] = Time.now

          txn_options
        end
      end
    end
  end

end
