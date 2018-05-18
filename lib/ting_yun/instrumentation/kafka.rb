# encoding: utf-8

module TingYun::Instrumentation::Kafka

  KAFKA_MIN_VERSION = '0.2.0'.freeze
  KAFKA_MAX_VERSION = '0.3.16'.freeze
  UNKNOWN = 'Unknown:Unknown'.freeze

  def self.version_support?
    if defined? RUBY_VERSION
      kafka_version = TingYun::Support::VersionNumber.new(Kafka::VERSION)
      kafka_version >= TingYun::Support::VersionNumber.new(KAFKA_MIN_VERSION) &&
          kafka_version <= TingYun::Support::VersionNumber.new(KAFKA_MAX_VERSION)
    else
      false
    end
  end
end

TingYun::Support::LibraryDetection.defer do
  named :ruby_kafka

  depends_on do
    begin
      require 'kafka'
      defined?(::Kafka)  &&
          TingYun::Instrumentation::Kafka.version_support? && false
    rescue LoadError
      false
    end
  end

  executes do
    TingYun::Agent.logger.info 'Installing Ruby-Kafka Instrumentation'
  end

  executes do
    Kafka::Producer.class_eval do
      attr_reader :cluster
    end

    if defined? (Kafka::Consumer)
      Kafka::Consumer.class_eval do
        attr_reader :cluster
      end
    end

    if defined? (Kafka::Cluster)
      Kafka::Cluster.class_eval do
        attr_reader :seed_brokers
      end
    end

    if defined?(Kafka::AsyncProducer) && defined?(Kafka::AsyncProducer::Worker)
      Kafka::AsyncProducer::Worker.class_eval do
        attr_reader :producer
      end
    end

    Kafka::Client.class_eval do
      if public_method_defined? :deliver_message
        alias_method :deliver_message_without_tingyun, :deliver_message

        def deliver_message(*args, **options, &block)
          begin
            state = TingYun::Agent::TransactionState.tl_get
            ip_and_hosts = @seed_brokers.map{|a| [a.host, a.port].join(':')}.join(',') rescue TingYun::Instrumentation::Kafka::UNKNOWN
            metric_name = "Message Kafka/#{ip_and_hosts}%2FTopic%2F#{options[:topic]}/Produce"
            summary_metrics = TingYun::Agent::Datastore::MetricHelper.metrics_for_message('Kafka', ip_and_hosts, 'Produce')
            TingYun::Agent::Transaction.wrap(state, metric_name, :Kafka, {}, summary_metrics) do
              TingYun::Agent.record_metric("#{metric_name}%2FByte", args[0].bytesize) if args[0]
              deliver_message_without_tingyun(*args, **options, &block)
            end
          rescue => e
            TingYun::Agent.logger.error("Failed to kafka deliver_message : ", e)
            deliver_message_without_tingyun(*args, **options, &block)
          end
        end
      end

      if public_method_defined?(:each_message)
        alias_method :each_message_without_tingyun, :each_message

        def each_message(*args, **options, &block)
          wrap_block = Proc.new do |message|
            begin
              state = TingYun::Agent::TransactionState.tl_get
              state.reset
              ip_and_hosts = @seed_brokers.map{|a| [a.host, a.port].join(':')}.join(',') rescue TingYun::Instrumentation::Kafka::UNKNOWN
              metric_name = "#{ip_and_hosts}%2FTopic%2F#{message.topic}/Consume"
              summary_metrics = TingYun::Agent::Datastore::MetricHelper.metrics_for_message('Kafka', ip_and_hosts, 'Consume')
              TingYun::Agent::Transaction.start(state,:message, {:transaction_name => "WebAction/Kafka/Topic%2F#{message.topic}/Consume"})
              TingYun::Agent::Transaction.wrap(state, "Message Kafka/#{metric_name}" , :Kafka, {}, summary_metrics)  do
                TingYun::Agent.record_metric("Message Kafka/#{metric_name}%2FByte",message.value.bytesize) if message.value
                block.call(message)
              end
            rescue => e
              TingYun::Agent.logger.error("Failed to kafka each_message in client : ", e)
              block.call(message)
            ensure
              TingYun::Agent::Transaction.stop(state, Time.now.to_f, summary_metrics)
            end
          end
          each_message_without_tingyun(*args, **options, &wrap_block)
        end
      end
    end

    if defined?(::Kafka::Consumer)
      Kafka::Consumer.class_eval do
        if public_method_defined?(:each_message)
          alias_method :each_message_without_tingyun, :each_message
          def each_message(*args, **options, &block)
            wrap_block = Proc.new do |message|
              begin
                state = TingYun::Agent::TransactionState.tl_get
                state.reset
                ip_and_hosts = self.cluster.seed_brokers.map{|a| [a.host, a.port].join(':')}.join(',') rescue TingYun::Instrumentation::Kafka::UNKNOWN
                metric_name = "#{ip_and_hosts}%2FTopic%2F#{message.topic}/Consume"
                summary_metrics = TingYun::Agent::Datastore::MetricHelper.metrics_for_message('Kafka', ip_and_hosts, 'Consume')
                TingYun::Agent::Transaction.start(state,:message, {:transaction_name => "WebAction/Kafka/Topic%2F#{message.topic}/Consume"})
                TingYun::Agent::Transaction.wrap(state, "Message Kafka/#{metric_name}" , :Kafka, {}, summary_metrics)  do
                  TingYun::Agent.record_metric("Message Kafka/#{metric_name}%2FByte", message.value.bytesize) if message.value
                  block.call(message)
                end
              rescue => e
                TingYun::Agent.logger.error("Failed to Bunny call_with_tingyun : ", e)
                block.call(message)
              ensure
                TingYun::Agent::Transaction.stop(state, Time.now.to_f, summary_metrics)
              end
            end
            if options.empty? && args.empty?
              each_message_without_tingyun(&wrap_block)
            else
              each_message_without_tingyun(*args, **options, &wrap_block)
            end
          end
        end

        if public_method_defined?(:each_batch)
          alias_method :each_batch_without_tingyun, :each_batch
          def each_batch(*args, **options, &block)
            wrap_block = Proc.new do |batch|
              begin
                state = TingYun::Agent::TransactionState.tl_get
                state.reset
                ip_and_hosts = self.cluster.seed_brokers.map{|a| [a.host, a.port].join(':')}.join(',') rescue TingYun::Instrumentation::Kafka::UNKNOWN
                metric_name = "#{ip_and_hosts}%2FTopic%2F#{batch.topic}/Consume"
                summary_metrics = TingYun::Agent::Datastore::MetricHelper.metrics_for_message('Kafka', ip_and_hosts, 'Consume')
                TingYun::Agent::Transaction.start(state,:message, {:transaction_name => "WebAction/Kafka/Topic%2F#{message.topic}/Consume"})
                TingYun::Agent::Transaction.wrap(state, "Message Kafka/#{metric_name}" , :Kafka, {}, summary_metrics)  do
                  bytesize = batch.messages.reduce(0){ |res, msg| res += (msg.value ? msg.value.bytesize : 0)}
                  TingYun::Agent.record_metric("Message Kafka/#{metric_name}%2FByte", bytesize) if bytesize.to_i > 0
                  block.call(batch)
                end
              rescue => e
                TingYun::Agent.logger.error("Failed to Bunny call_with_tingyun : ", e)
                block.call(batch)
              ensure
                TingYun::Agent::Transaction.stop(state, Time.now.to_f, summary_metrics)
              end
            end
            if options.empty? && args.empty?
              each_batch_without_tingyun(&wrap_block)
            else
              each_batch_without_tingyun(*args, **options, &wrap_block)
            end
          end
        end
      end
    end

    Kafka::Producer.class_eval do
      alias_method :produce_without_tingyun, :produce
      def produce(*args, **options, &block)
        begin
          state = TingYun::Agent::TransactionState.tl_get
          return produce_without_tingyun(*args, **options, &block) unless state.current_transaction
          ip_and_hosts = @cluster.seed_brokers.map{|a| [a.host, a.port].join(':')}.join(',') rescue TingYun::Instrumentation::Kafka::UNKNOWN
          metric_name = "Message Kafka/#{ip_and_hosts}%2FTopic%2F#{options[:topic]}/Produce"
          summary_metrics = TingYun::Agent::Datastore::MetricHelper.metrics_for_message('Kafka', ip_and_hosts, 'Produce')
          TingYun::Agent::Transaction.wrap(state, metric_name, :Kafka, {}, summary_metrics) do
            TingYun::Agent.record_metric("#{metric_name}%2FByte",args[0].bytesize) if args[0]
            produce_without_tingyun(*args, **options, &block)
          end
        rescue => e
          TingYun::Agent.logger.error("Failed to kafka produce sync : ", e)
          produce_without_tingyun(*args, **options, &block)
        end
      end
    end

    if defined?(Kafka::AsyncProducer)
      Kafka::AsyncProducer.class_eval do
        if public_method_defined? :produce
          alias_method :produce_without_tingyun, :produce

          def produce(*args, **options, &block)
            begin
              state = TingYun::Agent::TransactionState.tl_get
              ip_and_hosts = @worker.producer.cluster.seed_brokers.map{|a| [a.host, a.port].join(':')}.join(',') rescue TingYun::Instrumentation::Kafka::UNKNOWN
              metric_name = "Message Kafka/#{ip_and_hosts}%2FTopic%2F#{options[:topic]}/Produce"
              summary_metrics = TingYun::Agent::Datastore::MetricHelper.metrics_for_message('Kafka', ip_and_hosts, 'Produce')
              TingYun::Agent::Transaction.wrap(state, metric_name, :Kafka, {}, summary_metrics) do
                TingYun::Agent.record_metric("#{metric_name}%2FByte",args[0].bytesize) if args[0]
                produce_without_tingyun(*args, **options, &block)
              end
            rescue => e
              TingYun::Agent.logger.error("Failed to kafka produce async : ", e)
              produce_without_tingyun(*args, **options, &block)
            end
          end
        end
      end
    end
  end
end