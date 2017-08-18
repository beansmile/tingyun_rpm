# encoding: utf-8


require 'ting_yun/instrumentation/middleware_proxy'

TingYun::Support::LibraryDetection.defer do
  named :rails_middleware

  depends_on do
    defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i >= 3
  end

  depends_on do
    !::TingYun::Agent.config[:disable_middleware_instrumentation]
  end

  executes do
    ::TingYun::Agent.logger.info("Installing Rails 3+ middleware instrumentation")
    module ActionDispatch
      class MiddlewareStack
        class Middleware
          def build_with_ting_yun(app)
            # MiddlewareProxy.wrap guards against double-wrapping here.
            # We need to instrument the innermost app (usually a RouteSet),
            # which will never itself be the return value from #build, but will
            # instead be the initial value of the app argument.
            wrapped_app = ::TingYun::Instrumentation::MiddlewareProxy.wrap(app)
            result = build_without_ting_yun(wrapped_app)
            ::TingYun::Instrumentation::MiddlewareProxy.wrap(result)
          end

          alias_method :build_without_ting_yun, :build
          alias_method :build, :build_with_ting_yun
        end
      end
    end
  end
end
