# encoding: utf-8
require 'ting_yun/instrumentation/support/active_record_subscriber'

TingYun::Support::LibraryDetection.defer do
  named :active_record_4

  depends_on do
    !::TingYun::Agent.config[:disable_active_record]
  end

  depends_on do
    defined?(::ActiveRecord) && defined?(::ActiveRecord::Base) &&
        defined?(::ActiveRecord::VERSION) &&
        ::ActiveRecord::VERSION::MAJOR.to_i >= 4
  end

  depends_on do
    !TingYun::Instrumentation::Rails::ActiveRecordSubscriber.subscribed?
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing ActiveRecord 4 instrumentation'
  end

  executes do
    ActiveSupport::Notifications.subscribe('sql.active_record',
                                           TingYun::Instrumentation::Rails::ActiveRecordSubscriber.new)
    ::TingYun::Instrumentation::Support::ActiveRecordHelper.instrument_additional_methods
  end
end