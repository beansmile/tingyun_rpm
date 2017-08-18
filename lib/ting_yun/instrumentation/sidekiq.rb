# encoding: utf-8



TingYun::Support::LibraryDetection.defer do
  named :sidekiq

  depends_on do
    defined?(::Sidekiq) && !TingYun::Agent.config[:disable_sidekiq]
  end


  executes do
    TingYun::Agent.logger.info 'Installing Sidekiq Instrumentation'
    require 'ting_yun/instrumentation/support/controller_instrumentation'
  end

  executes do
    class TingYun::SidekiqInstrumentation
      include TingYun::Instrumentation::Support::ControllerInstrumentation
      def call(worker_instance, msg, queue, *_)
        trace_args = if worker_instance.respond_to?(:tingyun_trace_args)
                       worker_instance.tingyun_trace_args(msg, queue)
                     else
                       self.class.default_trace_args(msg)
                     end
        perform_action_with_tingyun_trace(trace_args) do
          TingYun::Agent.add_custom_params(:job_arguments, msg['args'])
          yield
        end
      end

      def self.default_trace_args(msg)
        {
            :name => 'perform',
            :class_name => msg['class'],
            :category => 'BackgroundAction/Sidekiq'
        }
      end
    end

    class Sidekiq::Extensions::DelayedClass
      def tingyun_trace_args(msg, queue)
        (target, method_name, _args) = YAML.load(msg['args'][0])
        {
            :name => method_name,
            :class_name => target.name,
            :category => 'BackgroundAction/Sidekiq'
        }
      rescue => e
        TingYun::Agent.logger.error("Failure during deserializing YAML for Sidekiq::Extensions::DelayedClass", e)
        TingYun::SidekiqInstrumentation.default_trace_args(msg)
      end
    end

    Sidekiq.configure_server do |config|
      config.server_middleware do |chain|
        chain.add TingYun::SidekiqInstrumentation
      end
    end
  end
end