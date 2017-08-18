# encoding: utf-8
require 'ting_yun/instrumentation/middleware_tracing'
require 'ting_yun/instrumentation/support/transaction_namer'

module TingYun
  module Instrumentation
    class MiddlewareProxy
      include TingYun::Instrumentation::MiddlewareTracing



      def self.is_sinatra_app?(target)
        defined?(::Sinatra::Base) && target.kind_of?(::Sinatra::Base)
      end

      def self.needs_wrapping?(target)
        !target.respond_to?(:_nr_has_middleware_tracing)
      end

      def self.wrap(target, is_app=false)
        if needs_wrapping?(target)
          self.new(target, is_app)
        else
          target
        end
      end


      attr_reader :target, :category, :transaction_options

      def initialize(target, is_app=false)
        @target            = target
        @is_app            = is_app
        @category          = determine_category
        @target_class_name = determine_class_name
        @transaction_name  = "#{determine_prefix}#{@target_class_name}/call"
        @transaction_options  = {
            :transaction_name => @transaction_name
        }
      end


      def determine_category
        if @is_app
          :rack
        else
          :middleware
        end
      end

      def determine_prefix
        TingYun::Instrumentation::Support::TransactionNamer.prefix_for_category(nil,@category)
      end

      def determine_class_name
        clazz = class_for_target

        name = clazz.name
        name = clazz.superclass.name if name.nil? || name == ""
        name
      end

      def class_for_target
        if @target.is_a?(Class)
          @target
        else
          @target.class
        end
      end

    end
  end
end

