# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

# == TingYun  Initialization
#
# When installed as a gem, you can activate the Ting Yun agent one of the following ways:
#
# For Rails, add:
#    config.gem 'tingyun_rpm'
# to your initialization sequence.
#
# For merb, do
#    dependency 'tingyun_rpm'
# in the Merb config/init.rb
#
# For Sinatra, do
#    require 'tingyun_rpm'
# after requiring 'sinatra'.
#
# For other frameworks, or to manage the agent manually, invoke TingYun::Agent#manual_start
# directly.
#

require 'ting_yun/frameworks'

#if the agent had started in manual , then shouldn't start in auto again

if defined?(Rails::VERSION)
  if Rails::VERSION::MAJOR.to_i >= 3
    module TingYun
      class Railtie < Rails::Railtie

          initializer "tingyun_rpm.start_plugin" do |app|
              TingYun::Agent.logger.info('initialize tingyun_rpm start_plugin')
              TingYun::Frameworks.init_start(:config => app.config)
          end
      end
    end
  else
      # After version 2.0 of Rails we can access the configuration directly.
      # We need it to add dev mode routes after initialization finished.
      config = nil
      config = Rails.configuration if Rails.respond_to?(:configuration)
      TingYun::Frameworks.init_start(:config => config)
  end
else
  TingYun::Frameworks.init_start
end
