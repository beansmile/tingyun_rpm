# encoding: utf-8
module TingYun
  module Frameworks
    class Ruby < TingYun::Frameworks::Framework
      def env
        @env ||= ENV['TINGYUN_ENV'] || ENV['RUBY_ENV'] || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
      end

      def root
        @root ||= ENV['APP_ROOT'] || '.'
      end

      def init_config(options={})
      end
    end
  end
end