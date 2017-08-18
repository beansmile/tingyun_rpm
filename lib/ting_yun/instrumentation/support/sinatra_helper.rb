# encoding: utf-8

module TingYun
  module Instrumentation
    module Support
      module SinatraHelper

        module_function

        SINATRA_MIN_VERSION = '1.2.3'.freeze
        SINATRA_MAX_VERSION = '1.4.8'.freeze

        def version_supported?
          TingYun::Support::VersionNumber.new(::Sinatra::VERSION) >= TingYun::Support::VersionNumber.new(SINATRA_MIN_VERSION)
          TingYun::Support::VersionNumber.new(::Sinatra::VERSION) <= TingYun::Support::VersionNumber.new(SINATRA_MAX_VERSION)
        end
      end
    end
  end
end
