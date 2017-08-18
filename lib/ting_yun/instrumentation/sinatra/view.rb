# encoding: utf-8

require 'ting_yun/agent/method_tracer_helpers'
require 'ting_yun/instrumentation/support/sinatra_helper'

TingYun::Support::LibraryDetection.defer do
  @name = :sinatra_view

  depends_on do
    !::TingYun::Agent.config[:disable_action_view]
  end

  depends_on do
    defined?(::Sinatra) && defined?(::Sinatra::Templates) && TingYun::Instrumentation::Support::SinatraHelper.version_supported?
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Sinatra view instrumentation'
  end

  executes do
    ::Sinatra::Templates.class_eval do

      def tingyun_template_metric(*args, &block)
        engine, data, options = args[0..2]
        eat_errors = options[:eat_errors]
        views = options[:views] || settings.views || "./views"
        if data.is_a?(Symbol)
          body, path, line = settings.templates[data]
          unless body.respond_to?(:call)
            template = Tilt[engine]
            found = false
            @preferred_extension = engine.to_s
            find_template(views, data, template) do |file|
              path ||= file
              if found = File.exist?(file)
                path = file
                break
              end
            end
            path = nil if eat_errors and not found  # layout_missing
          end
        else
          path = nil
        end
        if path
          path = path.gsub(settings.root,'') if respond_to?(:settings) && settings.root
          "View/#{path.gsub(/\.+\//,'')}/Rendering".squeeze("/")
        end
      end

      def render_with_tingyun(*args, &block) # engine, data, options = {}, locals = {}, &block
        scope_name = tingyun_template_metric(*args, &block)
        if scope_name
          TingYun::Agent::MethodTracerHelpers.trace_execution_scoped scope_name do
            render_without_tingyun(*args, &block)
          end
        else
          render_without_tingyun(*args, &block)
        end
      end

      alias_method :render_without_tingyun, :render
      alias_method :render, :render_with_tingyun
    end
  end
end