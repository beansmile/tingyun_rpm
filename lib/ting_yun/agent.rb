# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/configuration/manager'
require 'ting_yun/logger/startup_logger'
require 'ting_yun/frameworks'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/agent/transaction'
require 'ting_yun/agent/collector/middle_ware_collector/middle_ware'


module TingYun
  module Agent
    extend self

    @agent = nil
    @logger = nil
    @config = ::TingYun::Configuration::Manager.new

    attr_reader :config

    UNKNOWN_METRIC = '(unknown)'.freeze

    def agent
      return @agent if @agent
      TingYun::Agent.logger.warn("Agent unavailable as it hasn't been started.")
      nil
    end

    alias instance agent

    def agent=(new_instance)
      @agent = new_instance
    end


    def logger
      @logger || ::TingYun::Logger::StartupLogger.instance
    end

    def logger=(log)
      @logger = log
    end

    def reset_config
      @config.reset_to_defaults
    end



    # Record a value for the given metric name.
    #
    # This method should be used to record event-based metrics such as method
    # calls that are associated with a specific duration or magnitude.
    #
    # +metric_name+ should follow a slash separated path convention. Application
    # specific metrics should begin with "Custom/".
    #
    # +value+ should be either a single Numeric value representing the duration/
    # magnitude of the event being recorded, or a Hash containing :count,
    # :total, :min, :max, and :sum_of_squares keys. The latter form is useful
    # for recording pre-aggregated metrics collected externally.
    #
    # This method is safe to use from any thread.
    #
    # @api public
    def record_metric(metric_name, value, is_scoped=false ) #THREAD_LOCAL_ACCESS
      return unless agent
      stats = TingYun::Metrics::Stats.create_from_hash(value) if value.is_a?(Hash)
      if is_scoped
        agent.stats_engine.tl_record_scoped_metrics(metric_name, stats || value)
      else
        agent.stats_engine.tl_record_unscoped_metrics(metric_name, stats || value)
      end
    end

    # Manual agent configuration and startup/shutdown

    # Call this to manually start the Agent in situations where the Agent does
    # not auto-start.
    #
    # When the app environment loads, so does the Agent. However, the
    # Agent will only connect to the service if a web front-end is found. If
    # you want to selectively monitor ruby processes that don't use
    # web plugins, then call this method in your code and the Agent
    # will fire up and start reporting to the service.
    #
    # Options are passed in as overrides for values in the
    # tingyun.yml, such as app_name.  In addition, the option +log+
    # will take a logger that will be used instead of the standard
    # file logger.  The setting for the tingyun.yml section to use
    # (ie, RAILS_ENV) can be overridden with an :env argument.
    #
    # @api public
    #
    def manual_start(options={})
      raise "Options must be a hash" unless Hash === options
      TingYun::Frameworks.init_start({ :'nbs.agent_enabled' => true, :sync_startup => true }.merge(options))
    end

    # Yield to a block that is run with a database metric name context.  This means
    # the Database instrumentation will use this for the metric name if it does not
    # otherwise know about a model.  This is re-entrant.
    #
    # @param [String,Class,#to_s] model the DB model class
    #
    # @param [String] method the name of the finder method or other method to
    # identify the operation with.
    #
    def with_database_metric_name(model, method = nil, product = nil, &block) #THREAD_LOCAL_ACCESS
      if txn = TingYun::Agent::TransactionState.tl_get.current_transaction
        txn.with_database_metric_name(model, method, product, &block)
      else
        yield
      end
    end


    # Notice the error with the given available options:
    #
    # * <tt>:uri</tt> => Request path, minus request params or query string
    # * <tt>:metric</tt> => The metric name associated with the transaction
    # * <tt>:custom_params</tt> => Custom parameters
    #
    # @api public
    #
    def notice_error(exception, options={:type =>:exception})
      TingYun::Agent::Transaction.notice_error(exception, options)
      nil # don't return a noticed error datastructure. it can only hurt.
    end



    # Register this method as a callback for processes that fork
    # jobs.
    #
    # If the master/parent connects to the agent prior to forking the
    # agent in the forked process will use that agent_run.  Otherwise
    # the forked process will establish a new connection with the
    # server.
    #
    # Use this especially when you fork the process to run background
    # jobs or other work.  If you are doing this with a web dispatcher
    # that forks worker processes then you will need to force the
    # agent to reconnect, which it won't do by default.  Passenger and
    # Rainbows and Unicorn are already handled, nothing special needed for them.
    #
    # Options:
    # * <tt>:force_reconnect => true</tt> to force the spawned process to
    #   establish a new connection, such as when forking a long running process.
    #   The default is false--it will only connect to the server if the parent
    #   had not connected.
    # * <tt>:keep_retrying => false</tt> if we try to initiate a new
    #   connection, this tells me to only try it once so this method returns
    #   quickly if there is some kind of latency with the server.
    #
    # @api public
    #
    def after_fork(options={})
      agent.after_fork(options) if agent
    end


    # Yield to the block without collecting any metrics or traces in
    # any of the subsequent calls.  If executed recursively, will keep
    # track of the first entry point and turn on tracing again after
    # leaving that block.  This uses the thread local TransactionState.
    #
    # @api public
    #
    def disable_all_tracing
      return yield unless agent
      begin
        agent.push_trace_execution_flag(false)
        yield
      ensure
        agent.pop_trace_execution_flag
      end
    end




    # Shutdown the agent.  Call this before exiting.  Sends any queued data
    # and kills the background thread.
    #
    # @param options [Hash] Unused options Hash, for back compatibility only
    #
    # @api public
    #
    def shutdown
      agent.shutdown if agent
    end

    # if you wanna call the method, you must make sure current_transaction is not nil at first
    # if current_transaction
    #    add_custom_params(:key1,:value1)
    #    add_custom_params(:key2,:value2)
    # end
    # public api
    def add_custom_params(key, value)
      txn = TingYun::Agent::TransactionState.tl_get.current_transaction
      txn.attributes.add_custom_params(key, value) if txn
    end

    def tl_is_execution_traced?
      TingYun::Agent::TransactionState.tl_get.execution_traced?
    end

  end
end