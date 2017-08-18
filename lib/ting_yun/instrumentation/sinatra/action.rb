# encoding: utf-8

require 'ting_yun/instrumentation/support/split_controller'
require 'ting_yun/instrumentation/support/sinatra_helper'
module TingYun
  module Instrumentation
    module Sinatra
      module Action

        include TingYun::Instrumentation::Support::SplitController

        def tingyun_metric_path(current_class, path)
          if find_rule(request.request_method.upcase, path, request.env, request.params)
            return "Sinatra/#{current_class}/#{namespace}/#{name(path.slice(1..-1), request.env, request.params, request.cookies)}"
          else
            return self.env["PATH_INFO"] unless TingYun::Agent.config[:'nbs.auto_action_naming']
            "Sinatra/#{current_class}/#{path}(#{request.request_method.upcase})".squeeze("/")
          end
        end
      end
    end
  end
end


TingYun::Support::LibraryDetection.defer do
  @name = :sinatra_action

  depends_on do
    !::TingYun::Agent.config[:disable_action_controller]
  end

  depends_on do
    defined?(::Sinatra) && defined?(::Sinatra::Base) && TingYun::Instrumentation::Support::SinatraHelper.version_supported?
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Sinatra action instrumentation'
  end

  executes do
    ::Sinatra::Base.class_eval do

      class << self
        private
        alias :route_without_origin_path :route

        def route(verb, path, options = {}, &block)
          res = route_without_origin_path(verb, path, options = {}, &block)
          @routes[verb].last << path
          res
        end
      end


      private
      alias :route_eval_without_tingyun_trace :route_eval

      def ty_get_path(base)
        if routes = base.routes[@request.request_method]
          routes.each do |pattern, keys, conditions, block, origin_path|
            route = @request.path_info
            route = '/' if route.empty? and not settings.empty_path_info?
            next unless pattern.match(route)
            return (origin_path.respond_to?(:source) ? origin_path.source : origin_path)
          end
        end
        ty_get_path(base.superclass) if base.superclass.respond_to?(:routes)
      end


      def route_eval(*args, &block)

        self.class.class_eval do
          require 'ting_yun/instrumentation/support/parameter_filtering'
          require 'ting_yun/instrumentation/support/controller_instrumentation'
          include TingYun::Instrumentation::Sinatra::Action
        end

        params = TingYun::Instrumentation::Support::ParameterFiltering.flattened_filter_request_parameters(@params)

        TingYun::Instrumentation::Support::ControllerInstrumentation.perform_action_with_tingyun_trace(
            :category => :sinatra,
            :name     => @request.path_info,
            :path     => tingyun_metric_path(self.class.name, ty_get_path(self.class)),
            :params   => params,
            :class_name => self.class.name,
            :request => @request
        ) do
          route_eval_without_tingyun_trace(*args, &block)
        end
      end
    end
  end
end
