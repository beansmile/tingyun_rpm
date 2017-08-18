# encoding: utf-8

require 'ting_yun/instrumentation/support/action_cable_subscriber'

TingYun::Support::LibraryDetection.defer do
  named  :rails5_action_cable

  depends_on do
    !::TingYun::Agent.config[:disable_action_cable]
  end

  depends_on do
    defined?(::Rails) &&
        ::Rails::VERSION::MAJOR.to_i == 5 &&
        defined?(::ActionCable)
  end

  depends_on do
    !TingYun::Agent.config[:disable_action_cable_instrumentation]
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Rails 5 Action Cable instrumentation'
  end

  executes do
    # enumerate the specific events we want so that we do not get unexpected additions in the future
    ActiveSupport::Notifications.subscribe(/(perform_action|transmit)\.action_cable/,
                                           TingYun::Instrumentation::Rails::ActionCableSubscriber.new)
  end
end
