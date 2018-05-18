  # encoding: utf-8



TingYun::Support::LibraryDetection.defer do
  named :thrift

  depends_on do
    defined?(::Thrift) && defined?(::Thrift::Client) && defined?(::Thrift::BaseProtocol)
  end


  executes do
    TingYun::Agent.logger.info 'Installing Thrift Instrumentation'
    require 'ting_yun/support/serialize/json_wrapper'
    require 'ting_yun/instrumentation/support/external_helper'
  end

  executes do

    ::Thrift::BaseProtocol.class_eval do

      def skip_with_tingyun(type)
        begin
          data = skip_without_tingyun(type)
        ensure
          if data.is_a? ::String
            if data.include?("TingyunTxData")
              my_data = TingYun::Support::Serialize::JSONWrapper.load data.gsub("'",'"')
              TingYun::Agent::TransactionState.process_thrift_data(my_data["TingyunTxData"])

            end
          end
        end
      end


      alias :skip_without_tingyun :skip
      alias :skip  :skip_with_tingyun
    end

    ::Thrift::Client.module_eval do
      require 'ting_yun/instrumentation/support/thrift_helper'

      include TingYun::Instrumentation::ThriftHelper
      include TingYun::Instrumentation::Support::ExternalHelper

        def send_message_args_with_tingyun(args_class, args = {})
          return send_message_args_without_tingyun(args_class, args) unless TingYun::Agent.config[:'nbs.transaction_tracer.thrift'] && TingYun::Agent.config[:'nbs.transaction_tracer.enabled']
          begin
            state = TingYun::Agent::TransactionState.tl_get
            return  unless state.execution_traced?

            data = TingYun::Support::Serialize::JSONWrapper.dump("TingyunID" => create_tingyun_id("thrift"))
            TingYun::Agent.logger.info("thift will send TingyunID : ", data)
            @oprot.write_field_begin("TingyunField", 11, 40000)
            @oprot.write_string(data)
            @oprot.write_field_end
          rescue => e
            TingYun::Agent.logger.error("Failed to thrift send_message_args_with_tingyun : ", e)
          ensure
            send_message_args_without_tingyun(args_class, args)
          end
        end
        alias :send_message_args_without_tingyun :send_message_args
        alias :send_message_args  :send_message_args_with_tingyun


      def send_message_with_tingyun(name, args_class, args = {})

        begin
          tag = "#{args_class.to_s.split('::').first}.#{name}".downcase
          t0 = Time.now.to_f
          operations[tag] = {:started_time => t0}
          state = TingYun::Agent::TransactionState.tl_get
          return  unless state.execution_traced?
          stack = state.traced_method_stack
          node = stack.push_frame(state,:thrift,t0)
          operations[tag][:node] = node
        rescue => e
          TingYun::Agent.logger.debug("Failed to thrift send_message_with_tingyun : ", e)
        ensure
          send_message_without_tingyun(name, args_class, args)
        end

      end

      alias :send_message_without_tingyun :send_message
      alias :send_message  :send_message_with_tingyun

      def send_oneway_message_with_tingyun(name, args_class, args = {})

        begin
          tag = "#{args_class.to_s.split('::').first}.#{name}".downcase
          op_started = Time.now.to_f
          base, *other_metrics = metrics(tag)
          result = send_oneway_message_without_tingyun(name, args_class, args)
          duration = (Time.now.to_f - op_started)*1000
          TingYun::Agent.instance.stats_engine.tl_record_scoped_and_unscoped_metrics(base, other_metrics, duration)
          result
        rescue => e
          TingYun::Agent.logger.debug("Failed to thrift send_oneway_message_with_tingyun : ", e)
          return send_oneway_message_without_tingyun(name, args_class, args)
        end

      end
      alias :send_oneway_message_without_tingyun :send_oneway_message
      alias :send_oneway_message :send_oneway_message_with_tingyun

      def receive_message_with_tingyun(result_klass)
        begin
          state = TingYun::Agent::TransactionState.tl_get

          operate = operator(result_klass)

          t0, node =  started_time_and_node(operate)


          result = receive_message_without_tingyun(result_klass)
          unless result && result.success
            e = ::Thrift::ApplicationException.new(::Thrift::ApplicationException::MISSING_RESULT, "#{operate} failed: unknown result")
            ::TingYun::Instrumentation::Support::ExternalError.handle_error(e,metrics(operate)[0])
          end

          t1 = Time.now.to_f
          node_name, *other_metrics = metrics(operate)
          duration = TingYun::Helper.time_to_millis(t1 - t0)
          my_data = state.thrift_return_data || {}
          # net_block_duration = my_data["time"]? duration - my_data["time"]["duration"]- my_data["time"]["qu"] : duration
          # net_block_duration = duration if net_block_duration < 0
          TingYun::Agent.instance.stats_engine.tl_record_scoped_and_unscoped_metrics(
              node_name, other_metrics, duration
          )

          if my_data["time"]
            metrics_cross_app = metrics_for_cross_app(operate, my_data)
            _duration =  my_data["time"]["duration"] + my_data["time"]["qu"] + 0.1
            ::TingYun::Agent.instance.stats_engine.record_scoped_and_unscoped_metrics(state, metrics_cross_app.pop, metrics_cross_app, duration, _duration)
          end
          if node
            node.name = node_name
            ::TingYun::Agent::Collector::TransactionSampler.add_node_info(:uri => "thrift:#{tingyun_host}:#{tingyun_port}/#{operate}")
            stack = state.traced_method_stack
            stack.pop_frame(state, node, node_name, t1)
          end

          result
        rescue => e

          TingYun::Agent.logger.debug("Failed to thrift receive_message_with_tingyun : ", e)
          return  receive_message_without_tingyun(result_klass)
        end
      end

      alias :receive_message_without_tingyun :receive_message
      alias :receive_message :receive_message_with_tingyun
    end
  end
end