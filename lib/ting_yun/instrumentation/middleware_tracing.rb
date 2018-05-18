# encoding: utf-8

require 'ting_yun/agent/transaction/transaction_state'
require 'rack/request'
require 'ting_yun/instrumentation/support/queue_time'
require 'ting_yun/agent/transaction'
require 'ting_yun/agent'
require 'ting_yun/instrumentation/support/external_error'

module TingYun
  module Instrumentation
    module MiddlewareTracing
      TXN_STARTED_KEY = 'tingyun.transaction_started'.freeze unless defined?(TXN_STARTED_KEY)

      def _nr_has_middleware_tracing
        true
      end

      def build_transaction_options(env, first_middleware)
        opts = transaction_options
        opts = merge_first_middleware_options(opts, env) if first_middleware
        opts
      end

      def merge_first_middleware_options(opts, env)
        opts.merge(
            :request          => ::Rack::Request.new(env),
            :apdex_start_time => TingYun::Instrumentation::Support::QueueTime.parse_frontend_timestamp(env)
        )
      end

      def capture_http_response_code(state, result)
        if result.is_a?(Array) && state.current_transaction
          state.current_transaction.attributes.add_agent_attribute(:httpStatus, result[0].to_s)
        end
      end
      # the trailing unless is for the benefit for Ruby 1.8.7 and can be removed
      # when it is deprecated.
      CONTENT_TYPE = 'Content-Type'.freeze unless defined?(CONTENT_TYPE)

      def capture_response_content_type(state, result)
        if result.is_a?(Array) && state.current_transaction
          _, headers, _ = result
          state.current_transaction.attributes.add_agent_attribute(:contentType, headers[CONTENT_TYPE].to_s)
        end
      end

      def sinatra_static?(env)
        defined?(::Sinatra) && defined?(::Sinatra::Base) && env['REQUEST_URI'] && env['REQUEST_URI'] =~ /\.(css|js|html|png|jpg|jpeg|gif|bmp)\Z/i
      end

      def call(env)
        return target.call(env) if sinatra_static?(env)

        first_middleware = note_transaction_started(env)
        state = TingYun::Agent::TransactionState.tl_get
        begin

          if first_middleware
            events.notify(:cross_app_before_call, env)
          end
          TingYun::Agent::Transaction.start(state, category, build_transaction_options(env, first_middleware))

          result = (target == self) ? traced_call(env) : target.call(env)

          if first_middleware
            capture_http_response_code(state, result)
            capture_response_content_type(state, result)
            events.notify(:cross_app_after_call, result)
          end

          result
        rescue Exception => e
          TingYun::Agent.notice_error(e,:type=>:error)
          raise e
        ensure
          TingYun::Agent::Transaction.stop(state)
        end
      end


      def note_transaction_started(env)
        env[TXN_STARTED_KEY] = true unless env[TXN_STARTED_KEY]
      end

      def events
        ::TingYun::Agent.instance.events
      end
    end
  end
end
