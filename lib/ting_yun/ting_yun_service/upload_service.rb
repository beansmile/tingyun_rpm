# encoding: utf-8
require 'ting_yun/metrics/metric_spec'
require 'ting_yun/metrics/metric_data'
require 'ting_yun/support/serialize/encodes'
require 'ting_yun/support/quantile_p2'
require 'json'

module TingYun
  class TingYunService
    module UploadService

      EMPTY_PARENT = ''.freeze
      def compressed_json
        TingYun::Support::Serialize::Encoders::CompressedJSON
      end

      def base64_compressed_json
        TingYun::Support::Serialize::Encoders::Base64CompressedJSON
      end

      def json
        TingYun::Support::Serialize::Encoders::Json
      end

      def metric_data(stats_hash, base_quantile_hash)
        action_array, adpex_array, general_array, components_array, errors_array = build_metric_data_array(stats_hash, base_quantile_hash)

        upload_data = {
            :type => 'perfMetrics',
            :timeFrom => stats_hash.started_at.to_i,
            :timeTo => stats_hash.harvested_at.to_i || Time.now.to_i,
            :interval =>  TingYun::Agent.config[:data_report_period],
            :actions => action_array,
            :apdex => adpex_array,
            :components => components_array,
            :general => general_array,
            :errors  => errors_array
        }
        upload_data.merge!(:config => {"nbs.quantile" => TingYun::Agent.config[:'nbs.quantile']}) if TingYun::Agent.config[:'nbs.quantile']
        result = invoke_remote(:upload, [upload_data])
        self.quantile_cache = {}
        fill_metric_id_cache(result)
        result
      end


      # The collector wants to recieve metric data in a format that's different
      # # from how we store it inte -nally, so this method handles the translation.
      # # It also handles translating metric names to IDs using our metric ID cache.
      def build_metric_data_array(stats_hash, base_quantile_hash)
        action_array = []
        adpex_array = []
        general_array = []
        components_array = []
        errors_array = []

        calculate_quantile(base_quantile_hash.hash)

        stats_hash.each do |metric_spec, stats|

          # Omit empty stats as an optimization
          unless stats.is_reset?
            metric_id = metric_id_cache[metric_spec.hash]

            if metric_spec.name.start_with?('WebAction','BackgroundAction')
              action_array << generate_action(metric_spec, stats, metric_id)
            elsif metric_spec.name.start_with?('Apdex')
              adpex_array << TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id)
            elsif metric_spec.name.start_with?('Errors') && metric_spec.scope.empty?
              errors_array << TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id)
            else
              if metric_spec.scope.empty?
                general_array << TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id)  unless metric_spec.name.start_with?("View","Middleware","Nested","Rack")
              else
                components_array << TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id) unless metric_spec.name.start_with?("Nested")
              end
            end

          end
        end

        [action_array, adpex_array, general_array, components_array, errors_array]
      end

      def generate_action(metric_spec, stats, metric_id)
        if !TingYun::Support::QuantileP2.support? || metric_spec.name.start_with?('BackgroundAction')
          TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id)
        else
          quantile = self.quantile_cache[metric_spec.full_name] || []
          TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id, quantile)
        end
      end

      def calculate_quantile(base)
        if TingYun::Support::QuantileP2.support?
          quantile = TingYun::Agent.config[:'nbs.quantile']
          base.each do |action_name, base_list|
            qm = TingYun::Support::QuantileP2.new(JSON.parse(quantile).map{|i| i.to_f/100})
            base_list.each{ |l| qm.add(l) }
            self.quantile_cache[action_name] = qm.markers
          end
        end
      end


      # takes an array of arrays of spec and id, adds it into the
      # metric cache so we can save the collector some work by
      # sending integers instead of strings the next time around
      def fill_metric_id_cache(pairs_of_specs_and_ids)
        pairs_of_specs_and_ids.each do |_, value|
          if value.is_a? Array
            value.each do |array|
              if array.is_a? Array
                metric_id_cache[array[0]['name'].hash ^ (array[0]['parent']||EMPTY_PARENT).hash] = array[1]
              end
            end
          end
        end
      rescue => e
        # If we've gotten this far, we don't want this error to propagate and
        # make this post appear to have been non-successful, which would trigger
        # re-aggregation of the same metric data into the next post, so just log
        TingYun::Agent.logger.error("Failed to fill metric ID cache from response, error details follow ", e)
      end
    end

    def error_data(unsent_errors)
      upload_data = {
          :type => 'errorTraceData',
          :errors => unsent_errors
      }
      invoke_remote(:upload, [upload_data], :encoder=> json)
    end


    def action_trace_data(traces)
      upload_data = {
          :type => 'actionTraceData',
          :actionTraces => traces
      }
      invoke_remote(:upload, [upload_data], :encoder=> json)
    end


    def sql_trace(sql_trace)
      upload_data = {
          :type => 'sqlTraceData',
          :sqlTraces => sql_trace
      }

      invoke_remote(:upload, [upload_data], :encoder=> json)

    end

    def external_error_data(traces)
      upload_data = {
          :type => 'externalErrorTraceData',
          :errors => traces
      }
      invoke_remote(:upload, [upload_data], :encoder=> json)
    end
  end
end