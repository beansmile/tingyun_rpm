# encoding: utf-8

require 'ting_yun/agent/transaction/trace'


module TingYun
  module Agent
    class TransactionSampleBuilder

      class PlaceholderNode
        attr_reader :parent_node
        attr_accessor :depth

        def initialize(parent_node)
          @parent_node = parent_node
          @depth = 1
        end

        # No-op - some clients expect to be able to use these to read/write
        # params on TT nodes.
        def [](key); end
        def []=(key, value); end

        # Stubbed out in case clients try to touch params directly.
        def params; {}; end
        def params=; end
      end

      attr_reader :current_node, :trace

      def initialize(time=Time.now)
        @trace = TingYun::Agent::Transaction::Trace.new(time.to_f)
        @trace_start = time.to_f
        @current_node = @trace.root_node
      end

      def trace_entry(time)
        if @trace.node_count == 0
          node = @trace.create_node(time.to_f - @trace_start)
          @trace.root_node = node
          @current_node = node
          return @current_node
        end
        if @trace.node_count < node_limit
          node = @trace.create_node(time.to_f - @trace_start)
          @current_node.add_called_node(node)
          @current_node = node

          if @trace.node_count == node_limit
            ::TingYun::Agent.logger.debug("Node limit of #{node_limit} reached, ceasing collection.")
          end
        else
          if @current_node.is_a?(PlaceholderNode)
            @current_node.depth += 1
          else
            @current_node = PlaceholderNode.new(@current_node)
          end
        end
        @current_node
      end

      def trace_exit(metric_name, time, klass_name)
        if @current_node.is_a?(PlaceholderNode)
          @current_node.depth -= 1
          if @current_node.depth == 0
            @current_node = @current_node.parent_node
          end
        else
          @current_node.metric_name = metric_name
          @current_node.klass = klass_name
          @current_node.end_trace(time.to_f - @trace_start)
          @current_node = @current_node.parent_node
        end
      end

      def finish_trace(time=Time.now.to_f)

        if @trace.finished
          ::TingYun::Agent.logger.error "Unexpected double-finish_trace of Transaction Trace Object: \n#{@trace.to_s}"
          return
        end

        @trace.root_node.end_trace(time - @trace_start)

        @trace.threshold = transaction_trace_threshold
        @trace.finished = true
        @current_node = nil
      end


      def transaction_trace_threshold
        Agent.config[:'nbs.action_tracer.action_threshold']
      end


      def set_txId_and_txData(txid, txdata)
        @current_node[:txId] = txid
        @current_node[:txData] = txdata
      end

      def node_limit
        Agent.config[:'transaction_tracer.limit_segments']
      end

    end
  end
end
