# encoding: utf-8

require 'ting_yun/metrics/stats'
require 'ting_yun/support/helper'
require 'ting_yun/support/coerce'

module TingYun
  module Agent
    module Collector

      class SqlTrace < TingYun::Metrics::Stats

        attr_reader :action_metric_name
        attr_reader :uri
        attr_reader :sql
        attr_reader :slow_sql
        attr_reader :params

        def initialize(normalized_query, slow_sql, action_name, uri)
          super()
          @params = {}

          @action_metric_name = action_name
          @slow_sql = slow_sql
          @sql = normalized_query
          @uri = uri
          @params[:stacktrace] = slow_sql.backtrace
          record_data_point(float(slow_sql.duration))
        end

        def aggregate(slow_sql, action_name, uri)
          duration = slow_sql.duration
          if duration > max_call_time
            @action_metric_name = action_name
            @slow_sql = slow_sql
            @uri = uri
            @params[:stacktrace] = slow_sql.backtrace
          end
          record_data_point(float(duration))
        end


        def prepare_to_send
          @sql = @slow_sql.sql unless Agent.config[:'nbs.action_tracer.record_sql'].to_s == 'obfuscated'
          @params[:explainPlan] = @slow_sql.explain if need_to_explain?
        end


        def need_to_explain?
          Agent.config[:'nbs.action_tracer.explain_enabled'] &&  @slow_sql.duration * 1000 > TingYun::Agent.config[:'nbs.action_tracer.explain_threshold']
        end


        include TingYun::Support::Coerce

        def to_collector_array(encoder)
          [
              @slow_sql.start_time,
              string(@action_metric_name),
              string(@slow_sql.metric_name),
              string(@uri||@action_metric_name),
              string(@sql),
              int(@call_count),
              TingYun::Helper.time_to_millis(@total_call_time),
              TingYun::Helper.time_to_millis(@max_call_time),
              TingYun::Helper.time_to_millis(@min_call_time),
              encoder.encode(@params)
          ]
        end
      end
    end
  end
end
