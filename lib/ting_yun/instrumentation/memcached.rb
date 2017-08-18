# encoding: utf-8
module TingYun
  module Instrumentation
    module Timings
      def record_memcached_duration(duration)
        state = TingYun::Agent::TransactionState.tl_get
        if state
          state.timings.mc_duration = state.timings.mc_duration + duration * 1000
        end
      end
    end

    module VersionSupport
      require 'ting_yun/support/version_number'
      module_function

      VERSION1 = '2.6.4'.freeze

      def new_version_support?
        ::TingYun::Support::VersionNumber.new(Dalli::VERSION) >= ::TingYun::Support::VersionNumber.new(VERSION1)
      end
    end
  end
end


TingYun::Support::LibraryDetection.defer do
  named :memcached

  depends_on do
    defined?(::Memcached) || (defined?(::Dalli) && defined?(::Dalli::Client)) && false
  end

  depends_on do
    !::TingYun::Agent.config[:disable_memcache]
  end


  executes do
    TingYun::Agent.logger.info "Installing Memcached Instrumentation" if defined?(::Memcached)
    TingYun::Agent.logger.info "Installing Dalli Instrumentation" if defined?(::Dalli::Client)
    require 'ting_yun/agent/transaction/transaction_state'
  end

  executes do
    require 'ting_yun/agent/datastore'

    if defined?(::Memcached)
      ::Memcached.class_eval do

        include TingYun::Instrumentation::Timings

        methods = [:set, :add, :increment, :decrement, :replace, :append, :prepend, :cas, :delete, :flush, :get, :exist,
                   :get_from_last, :server_by_key, :stats, :set_servers]

        methods.each do |method|
          next unless public_method_defined? method

          alias_method "#{method}_without_tingyun_trace".to_sym, method.to_sym

          define_method method do |*args, &block|
            TingYun::Agent::Datastore.wrap('Memcached', method.to_s, nil, nil, nil, nil, method(:record_memcached_duration)) do
              send "#{method}_without_tingyun_trace", *args, &block
            end
          end
        end

        alias :incr :increment
        alias :decr :decrement
        alias :compare_and_swap :cas if public_method_defined? :compare_and_swap
      end
    end

    if defined?(::Dalli::Server)
      ::Dalli::Server.class_eval do

        include TingYun::Instrumentation::Timings

        connect_method = (private_method_defined? :connect) ? :connect : :connection
        private
        alias_method :connect_without_tingyun_trace, connect_method

        define_method connect_method do |*args, &block|
          if @sock
            connect_without_tingyun_trace *args, &block
          else
            TingYun::Agent::Datastore.wrap('Memcached', 'connect', nil, hostname, port, nil, method(:record_memcached_duration)) do
              connect_without_tingyun_trace *args, &block
            end
          end
        end
      end
    end

    if defined?(::Dalli::Client)
      ::Dalli::Client.class_eval do

        include TingYun::Instrumentation::Timings

        private
        alias_method :perform_without_tingyun_trace, :perform
        def perform(*args, &block)
          return block.call if block
          op, key = args[0..1]
          current_ring = self.class.private_method_defined?(:ring) ? ring : @ring
          server = current_ring.server_for_key(validate_key(key.to_s)) rescue nil
          if server
            host = server.hostname
            port = server.port
          end
          TingYun::Agent::Datastore.wrap('Memcached', op.to_s, nil, host, port, nil, method(:record_memcached_duration)) do
            perform_without_tingyun_trace(*args, &block)
          end
        end

        methods = [:flush, :stats, :reset_stats, :close]
        methods += [:get_multi, :get_multi_cas] if TingYun::Instrumentation::VersionSupport.new_version_support?

        methods.each do |method|
          next unless public_method_defined? method
          alias_method "#{method}_without_tingyun_trace".to_sym, method.to_sym

          define_method method do |*args, &block|
            TingYun::Agent::Datastore.wrap('Memcached', method.to_s, nil, nil, nil, nil, method(:record_memcached_duration)) do
              send "#{method}_without_tingyun_trace", *args, &block
            end
          end
        end

        alias :flush_all :flush
        alias :reset :close if public_method_defined? :reset
      end
    end
  end
end