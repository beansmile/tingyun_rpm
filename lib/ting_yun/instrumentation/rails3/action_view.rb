# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/agent/method_tracer_helpers'

module TingYun
  module Instrumentation
    module Rails3
      module ActionView
        extend self

        def template_metric(identifier, options = {})
          if options[:file]
            "file"
          elsif identifier.nil?
            ::TingYun::Agent::UNKNOWN_METRIC
          elsif identifier.include? '/' # this is a filepath
            identifier.split('/')[-2..-1].join('/')
          else
            identifier
          end
        end
        def render_type(file_path)
          file = File.basename(file_path)
          if file.starts_with?('_')
            return 'Partial'
          else
            return 'Rendering'
          end
        end
      end
    end
  end
end


TingYun::Support::LibraryDetection.defer do
  @name = :rails31_view

  # We can't be sure that this will work with future versions of Rails 3.
  # Currently enabled for Rails 3.1 and 3.2
  depends_on do
    !::TingYun::Agent.config[:disable_action_view]
  end

  depends_on do
    defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i == 3 && ([1,2].member?(::Rails::VERSION::MINOR.to_i))
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Rails 3.1/3.2 view instrumentation'
  end

  executes do
    ActionView::TemplateRenderer.class_eval do
      # namespaced helper methods

      def render_with_tingyun(context, options)
        # This is needed for rails 3.2 compatibility
        @details = extract_details(options) if respond_to? :extract_details, true
        identifier = determine_template(options) ? determine_template(options).identifier : nil
        scope_name = "View/#{TingYun::Instrumentation::Rails3::ActionView.template_metric(identifier, options)}/Rendering"
        TingYun::Agent::MethodTracerHelpers.trace_execution_scoped scope_name do
          render_without_tingyun(context, options)
        end
      end

      alias_method :render_without_tingyun, :render
      alias_method :render, :render_with_tingyun
    end

    ActionView::PartialRenderer.class_eval do

      def instrument_with_tingyun(name, payload = {}, &block)
        identifier = payload[:identifier]
        scope_name = "View/#{TingYun::Instrumentation::Rails3::ActionView.template_metric(identifier)}/Partial"
        TingYun::Agent::MethodTracerHelpers.trace_execution_scoped(scope_name) do
          instrument_without_tingyun(name, payload, &block)
        end
      end

      alias_method :instrument_without_tingyun, :instrument
      alias_method :instrument, :instrument_with_tingyun
    end
  end
end


TingYun::Support::LibraryDetection.defer do
  @name = :rails30_view

  depends_on do
    defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i == 3 && ::Rails::VERSION::MINOR.to_i == 0
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Rails 3.0 view instrumentation'
  end

  executes do
    ActionView::Template.class_eval do
      def render_with_tingyun(*args, &block)
        options = if @virtual_path && @virtual_path.starts_with?('/') # file render
                    {:file => true }
                  else
                    {}
                  end
        str = "View/#{TingYun::Instrumentation::Rails3::ActionView.template_metric(@identifier, options)}/#{TingYun::Agent::Instrumentation::Rails3::ActionView.render_type(@identifier)}"
        TingYun::Agent::MethodTracerHelpers.trace_execution_scoped str do
          render_without_tingyun(*args, &block)
        end
      end

      alias_method :render_without_tingyun, :render
      alias_method :render, :render_with_tingyun

    end
  end
end