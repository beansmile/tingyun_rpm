# encoding: utf-8
require 'ting_yun/support/helper'
require 'ting_yun/support/coerce'
require 'ting_yun/agent/database'


module TingYun
  module Agent
    class Transaction
      class TraceNode

        attr_reader :entry_timestamp, :parent_node, :called_nodes
        attr_accessor :metric_name, :exit_timestamp, :uri, :count, :klass, :method, :name



        UNKNOWN_NODE_NAME = '<unknown>'.freeze


        def initialize(timestamp, metric_name)
          @entry_timestamp = timestamp
          @metric_name     = metric_name || UNKNOWN_NODE_NAME
          @called_nodes    = nil
          @count           = 1
        end

        def add_called_node(s)
          @called_nodes ||= []
          @called_nodes << s
          s.parent_node = self
        end

        def end_trace(timestamp)
          @exit_timestamp = timestamp
        end

        # return the total duration of this node
        def duration
          TingYun::Helper.time_to_millis(@exit_timestamp - @entry_timestamp)
        end


        def pre_metric_name(metric_name)
         @name ||= if metric_name.start_with?('Database ')
            "#{metric_name.split('/')[0]}%2F#{metric_name.split('%2F')[-1]}"
          else
            metric_name
          end
        end

        def to_array
          [TingYun::Helper.time_to_millis(entry_timestamp),
           TingYun::Helper.time_to_millis(exit_timestamp),
           TingYun::Support::Coerce.string(metric_name),
           TingYun::Support::Coerce.string(uri)||'',
           TingYun::Support::Coerce.int(count),
           TingYun::Support::Coerce.string(klass)||TingYun::Support::Coerce.string(pre_metric_name(metric_name)),
           TingYun::Support::Coerce.string(method)||'',
           params] +
           [(@called_nodes ? @called_nodes.map{|s| s.to_array} : [])]
        end

        def custom_params
          {}
        end

        def request_params
          {}
        end

        def []=(key, value)
          # only create a parameters field if a parameter is set; this will save
          # bandwidth etc as most nodes have no parameters
          params[key] = value
        end

        def [](key)
          params[key]
        end

        def params
          @params ||= {}
        end

        def params=(p)
          @params = p
        end

        def merge(hash)
          params.merge! hash
        end

        def each_call(&blk)
          blk.call self

          if @called_nodes
            @called_nodes.each do |node|
              node.each_call(&blk)
            end
          end
        end

        def explain_sql
          return params[:explainPlan] if params.key?(:explainPlan)

          statement = params[:sql]
          return nil unless statement.respond_to?(:config) &&
              statement.respond_to?(:explainer)

          TingYun::Agent::Database.explain_sql(statement)
        end

        protected
        def parent_node=(s)
          @parent_node = s
        end
      end
    end
  end
end
