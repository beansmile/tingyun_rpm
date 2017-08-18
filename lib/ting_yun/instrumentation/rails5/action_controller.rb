# encoding: utf-8

require 'ting_yun/instrumentation/support/action_controller_subscriber'


TingYun::Support::LibraryDetection.defer do
  named :rails5_controller

  depends_on do
    !::TingYun::Agent.config[:disable_action_controller]
  end

  depends_on do
    defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i == 5
  end

  depends_on do
    defined?(ActionController) && defined?(ActionController::Base)
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Rails 5 Controller instrumentation'
  end

  executes do
    ::TingYun::Instrumentation::Rails::ActionControllerSubscriber \
      .subscribe(/^process_action.action_controller$/)
  end
end
