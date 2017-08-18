# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/support/system_info'

module TingYun
  # The EnvironmentReport is responsible for analyzing the application's
  # environment and generating the data for the Environment Report in TINGYUN
  #
  # It contains useful system information like Ruby version, OS, loaded gems,
  # etc.
  #
  # Additional logic can be registered by using the EnvironmentReport.report_on
  # hook.
  class EnvironmentReport

    # This is the main interface for registering logic that should be included
    # in the Environment Report. For example:
    #
    # EnvironmentReport.report_on "Day of week" do
    #   Time.now.strftime("%A")
    # end
    #
    # The passed blocks will be run in EnvironmentReport instances on #initialize.
    #
    # Errors raised in passed blocks will be handled and logged at debug, so it
    # is safe to report on things that may not work in certain environments.
    #
    # The blocks should only return strings or arrays full of strings.  Falsey
    # values will be ignored.
    def self.report_on(key, &block)
      registered_reporters[key] = block
    end

    def self.registered_reporters
      @registered_reporters ||= Hash.new
    end

    # allow the logic to be swapped out in tests
    def self.registered_reporters=(logic)
      @registered_reporters = logic
    end

    # register reporting logic
    ####################################
    report_on('Gems') do
      begin
       (Bundler.rubygems.all_specs.map { |gem| "#{gem.name}(#{gem.version})" }).join(',')
      rescue
        # There are certain rubygem, bundler, rails combinations (e.g. gem
        # 1.6.2, rails 2.3, bundler 1.2.3) where the code above throws an error
        # in bundler because of rails monkey patching gem.  The below does work
        # though so try it if the above fails.
        Bundler.load.specs.map do |spec|
          version = (spec.respond_to?(:version) && spec.version)
          spec.name + (version ? "(#{version})" : "")
        end.join(',')
      end
    end
    report_on('Plugin List') { ::Rails.configuration.plugins.to_a.join(',')}
    report_on('Ruby version') { RUBY_VERSION }
    report_on('Ruby description') { RUBY_DESCRIPTION }
    report_on('Ruby platform') { RUBY_PLATFORM }
    report_on('Ruby patchlevel') { RUBY_PATCHLEVEL.to_s }
    report_on('JRuby version') { JRUBY_VERSION }
    report_on('Java VM version') { ENV_JAVA['java.vm.version'] }
    report_on('Logical Processors') { ::TingYun::Support::SystemInfo.num_logical_processors }
    report_on('Physical Cores') { ::TingYun::Support::SystemInfo.num_physical_cores }
    report_on('os_arch') { ::TingYun::Support::SystemInfo.processor_arch }
    report_on('os_version') { ::TingYun::Support::SystemInfo.os_version }
    report_on('kernel') { ::TingYun::Support::SystemInfo.ruby_os_identifier }
    report_on('Database adapter') do
      ActiveRecord::Base.configurations[::TingYun::Frameworks.framework.env]['adapter']
    end
    report_on('Framework') { TingYun::Agent.config[:framework].to_s }
    report_on('Dispatcher') { TingYun::Agent.config[:dispatcher].to_s }
    report_on('Environment') { ::TingYun::Frameworks.framework.env }
    report_on('Rails version') { ::Rails::VERSION::STRING }
    report_on('Rails threadsafe') do
      ::Rails.configuration.action_controller.allow_concurrency
    end
    report_on('Rails Env') do
      if defined? ::Rails and ::Rails.respond_to?(:env)
        ::Rails.env.to_s
      else
        ENV['RAILS_ENV']
      end
    end
    report_on('OpenSSL version') { ::OpenSSL::OPENSSL_VERSION }
    # end reporting logic
    ####################################


    attr_reader :data
    # Generate the report based on the class level logic.
    def initialize
      @data = self.class.registered_reporters.inject(Hash.new) do |data, (key, logic)|
        begin
          value = logic.call
          if value
            data[key] = value
          else
            ::TingYun::Agent.logger.debug("EnvironmentReport ignoring value for #{key.inspect} which came back falsey: #{value.inspect}")
          end
        rescue => e
          ::TingYun::Agent.logger.debug("EnvironmentReport failed to retrieve value for #{key.inspect}: #{e}")
        end
        data
      end
    end

    def [](key)
      @data[key]
    end

    def []=(key, value)
      @data[key] = value
    end

    def to_a
      @data.to_a
    end
  end
end
