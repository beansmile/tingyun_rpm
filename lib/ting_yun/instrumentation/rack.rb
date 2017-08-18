# encoding: utf-8

require 'ting_yun/instrumentation/middleware_proxy'
require 'ting_yun/support/version_number'



module TingYun
  module Instrumentation

    module RackHelpers
      extend self

      def middleware_instrumentation_enabled?
        version_supported? && !::TingYun::Agent.config[:disable_middleware_instrumentation]
      end

      def version_supported?
        rack_version_supported?
      end

      def rack_version_supported?
        return false unless defined? ::Rack

        version = ::TingYun::Support::VersionNumber.new(::Rack.release)
        min_version = ::TingYun::Support::VersionNumber.new('1.1.0')
        version >= min_version
      end
    end

    module RackBuilder
      def run_with_tingyun(app, *args)
        if ::TingYun::Instrumentation::RackHelpers.middleware_instrumentation_enabled?
          wrapped_app = ::TingYun::Instrumentation::MiddlewareProxy.wrap(app, true)
          run_without_tingyun(wrapped_app, *args)
        else
          run_without_tingyun(app, *args)
        end
      end


      # def use_with_tingyun(middleware_class, *args, &blk)
      #   if ::TingYun::Instrumentation::RackHelpers.middleware_instrumentation_enabled?
      #     wrapped_middleware_class = ::TingYun::Instrumentation::MiddlewareProxy.for_class(middleware_class)
      #     use_without_tingyun(wrapped_middleware_class, *args, &blk)
      #   else
      #     use_without_tingyun(middleware_class, *args, &blk)
      #   end
      # end

      # We patch this method for a reason that actually has nothing to do with
      # instrumenting rack itself. It happens to be a convenient and
      # easy-to-hook point that happens late in the startup sequence of almost
      # every application, making it a good place to do a final call to
      # LibraryDetection.detect!, since all libraries are likely loaded at
      # this point.
      def to_app_with_tingyun_deferred_dependency_detection
        unless ::Rack::Builder._nr_deferred_detection_ran
          TingYun::Agent.logger.info "Doing deferred library-detection before Rack startup"
          TingYun::Support::LibraryDetection.detect!
          ::Rack::Builder._nr_deferred_detection_ran = true
        end
        to_app_without_tingyun
      end
    end
  end
end





TingYun::Support::LibraryDetection.defer do

  named :rack

  depends_on do
    defined?(::Rack) && defined?(::Rack::Builder)
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing deferred Rack instrumentation'

    class ::Rack::Builder
      class << self
        attr_accessor :_nr_deferred_detection_ran
      end

      self._nr_deferred_detection_ran = false

      include ::TingYun::Instrumentation::RackBuilder

      alias_method :to_app_without_tingyun, :to_app
      alias_method :to_app, :to_app_with_tingyun_deferred_dependency_detection

      unless TingYun::Agent.config[:disable_middleware_instrumentation]
        ::TingYun::Agent.logger.info 'Installing Rack::Builder middleware instrumentation'

        alias_method :run_without_tingyun, :run
        alias_method :run, :run_with_tingyun
        #
        # alias_method :use_without_tingyun, :use
        # alias_method :use, :use_with_tingyun
      end

    end
  end
end