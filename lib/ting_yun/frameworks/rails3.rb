# encoding: utf-8

require 'ting_yun/frameworks/rails'

module TingYun
  module Frameworks
    class Rails3 < TingYun::Frameworks::Rails

      def env
        @env ||= ::Rails.env.to_s
      end

      def rails_root
        ::Rails.root.to_s
      end

      def vendor_root
        @vendor_root ||= File.join(root, 'vendor', 'rails')
      end

      def version
        @rails_version ||= TingYun::Support::VersionNumber.new(::Rails::VERSION::STRING)
      end
    end
  end
end