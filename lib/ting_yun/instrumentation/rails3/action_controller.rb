# encoding: utf-8
require 'ting_yun/agent'
require 'ting_yun/instrumentation/support/controller_instrumentation'
require 'ting_yun/instrumentation/support/parameter_filtering'
require 'ting_yun/instrumentation/support/split_controller'

module TingYun
  module Instrumentation
    module Rails3
      module ActionController

        include TingYun::Instrumentation::Support::SplitController



        def tingyun_metric_path(action_name_override = nil)
          if find_rule(request.request_method.upcase, request.path, request.env, request.filtered_parameters)
            return "Rails/#{namespace}/#{name(request.path.slice(1..-1), request.env, request.filtered_parameters, request.cookies)}"
          else
            return  "URL/#{self.env["PATH_INFO"][1..-1].gsub(/\//,'%2F')}" unless TingYun::Agent.config[:'nbs.auto_action_naming']

            action = action_name_override || action_name
            if action_name_override || self.class.action_methods.include?(action)
              "Rails/#{self.class.controller_path}%2F#{action}"
            else
              "Rails/#{self.class.controller_path}%2F(other)"
            end
          end
        end


        def process_action(*args)
          params = TingYun::Instrumentation::Support::ParameterFiltering.flattened_filter_request_parameters(request.filtered_parameters)
          perform_action_with_tingyun_trace(:category => :controller,
                                            :name     => self.action_name,
                                            :path     => tingyun_metric_path,
                                            :params   => params,
                                            :class_name => self.class.name) do
            super
          end
        end
      end
    end
  end
end


TingYun::Support::LibraryDetection.defer do
  @name = :rails3_controller

  depends_on do
    !::TingYun::Agent.config[:disable_action_controller]
  end

  depends_on do
    defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i == 3
  end

  depends_on do
    defined?(ActionController) && defined?(ActionController::Base)
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Rails 3 Controller instrumentation'
  end

  executes do
    class ActionController::Base
      include TingYun::Instrumentation::Support::ControllerInstrumentation
      include TingYun::Instrumentation::Rails3::ActionController
    end
  end
end

