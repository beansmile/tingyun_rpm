# encoding: utf-8

require 'ting_yun/agent'

module TingYun
  module Support
    class Collector <  Struct.new :name, :port
      def to_s; "#{name}:#{port}"; end
    end

    module CollectorMethods
      def collector
        @remote_collector ||= collector_from_host
      end

      def api_collector
        @api_collector ||= Collector.new(TingYun::Agent.config[:api_host], TingYun::Agent.config[:api_port])
      end

      def collector_from_host(hostname=nil)
        if hostname.nil?
          Collector.new(TingYun::Agent.config[:host], TingYun::Agent.config[:port])
        else
          args = hostname.split(':')
          Collector.new(args[0], args[1]||TingYun::Agent.config[:port])
        end

      end

    end

    extend CollectorMethods

  end
end
