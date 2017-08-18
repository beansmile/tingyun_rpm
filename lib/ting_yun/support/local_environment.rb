# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

module TingYun
  module Support
    class LocalEnvironment

      def discovered_dispatcher
        discover_dispatcher unless @discovered_dispatcher
        @discovered_dispatcher
      end

      def initialize
        # Extend self with any any submodules of LocalEnvironment.  These can override
        # the discover methods to discover new framworks and dispatchers.
        TingYun::Support::LocalEnvironment.constants.each do | const |
          mod = TingYun::Support::LocalEnvironment.const_get const
          self.extend mod if mod.instance_of? Module
        end
        @discovered_dispatcher = nil
        discover_dispatcher
      end

      # Runs through all the objects in ObjectSpace to find the first one that
      # match the provided class
      def self.find_class_in_object_space(klass)
        if TingYun::Support::LanguageSupport.object_space_usable?
          ObjectSpace.each_object(klass) do |x|
            return x
          end
        end
        return nil
      end


      private

      def discover_dispatcher
        dispatchers = %w[
        passenger
        torquebox
        trinidad
        glassfish
        resque
        sidekiq
        delayed_job
        puma
        thin
        mongrel
        litespeed
        webrick
        fastcgi
        rainbows
        unicorn
      ]
        while dispatchers.any? && !@discovered_dispatcher
          send 'check_for_'+(dispatchers.shift)
        end
      end


      def check_for_torquebox
        return unless defined?(::JRuby) &&
            ( org.torquebox::TorqueBox rescue nil)
        @discovered_dispatcher = :torquebox
      end

      def check_for_glassfish
        return unless defined?(::JRuby) &&
            (((com.sun.grizzly.jruby.rack.DefaultRackApplicationFactory rescue nil) &&
                defined?(com::sun::grizzly::jruby::rack::DefaultRackApplicationFactory)) ||
                (jruby_rack? && defined?(::GlassFish::Server)))
        @discovered_dispatcher = :glassfish
      end

      def check_for_trinidad
        return unless defined?(::JRuby) && jruby_rack? && defined?(::Trinidad::Server)
        @discovered_dispatcher = :trinidad
      end

      def jruby_rack?
        defined?(JRuby::Rack::VERSION)
      end

      def check_for_webrick
        return unless defined?(::WEBrick) && defined?(::WEBrick::VERSION)
        @discovered_dispatcher = :webrick
      end

      def check_for_fastcgi
        return unless defined?(::FCGI)
        @discovered_dispatcher = :fastcgi
      end

      # this case covers starting by mongrel_rails
      def check_for_mongrel
        return unless defined?(::Mongrel) && defined?(::Mongrel::HttpServer)
        @discovered_dispatcher = :mongrel
      end

      def check_for_unicorn
        if (defined?(::Unicorn) && defined?(::Unicorn::HttpServer)) && TingYun::Support::LanguageSupport.object_space_usable?
          _v = TingYun::Support::LocalEnvironment.find_class_in_object_space(::Unicorn::HttpServer)
          @discovered_dispatcher = :unicorn if _v
        end
      end

      def check_for_rainbows
        if (defined?(::Rainbows) && defined?(::Rainbows::HttpServer)) && TingYun::Support::LanguageSupport.object_space_usable?
          _v = TingYun::Support::LocalEnvironment.find_class_in_object_space(::Rainbows::HttpServer)
          @discovered_dispatcher = :rainbows if _v
        end
      end

      def check_for_puma
        if defined?(::Puma) && $0.include?('puma')
          @discovered_dispatcher = :puma
        end
      end

      def check_for_delayed_job
        if $0 =~ /delayed_job$/ || (File.basename($0) == 'rake' && ARGV.include?('jobs:work'))
          @discovered_dispatcher = :delayed_job
        end
      end

      def check_for_resque
        has_queue              = ENV['QUEUE'] || ENV['QUEUES']
        resque_rake            = executable == 'rake' && ARGV.include?('resque:work')
        resque_pool_rake       = executable == 'rake' && ARGV.include?('resque:pool')
        resque_pool_executable = executable == 'resque-pool' && defined?(::Resque::Pool)

        using_resque = defined?(::Resque) &&
            (has_queue && resque_rake) ||
            (resque_pool_executable || resque_pool_rake)

        @discovered_dispatcher = :resque if using_resque
      end

      def check_for_sidekiq
        if defined?(::Sidekiq) && File.basename($0) == 'sidekiq'
          @discovered_dispatcher = :sidekiq
        end
      end

      def check_for_thin
        if defined?(::Thin) && defined?(::Thin::Server)
          # If ObjectSpace is available, use it to search for a Thin::Server
          # instance. Otherwise, just the presence of the constant is sufficient.
          if TingYun::Support::LanguageSupport.object_space_usable?
            ObjectSpace.each_object(Thin::Server) do |thin_dispatcher|
              @discovered_dispatcher = :thin
            end
          else
            @discovered_dispatcher = :thin
          end
        end
      end

      def check_for_litespeed
        if caller.pop =~ /fcgi-bin\/RailsRunner\.rb/
          @discovered_dispatcher = :litespeed
        end
      end

      def check_for_passenger
        if defined?(::PhusionPassenger)
          @discovered_dispatcher = :passenger
        end
      end

      public
      # outputs a human-readable description
      def to_s
        s = "LocalEnvironment["
        s << ";dispatcher=#{@discovered_dispatcher}" if @discovered_dispatcher
        s << "]"
      end

      def executable
        File.basename($0)
      end
    end
  end
end
