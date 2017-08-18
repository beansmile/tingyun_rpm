# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require 'ting_yun/configuration/dotted_hash'

module TingYun
  module Configuration
    class ServerSource < DottedHash
      # These keys appear *outside* of the agent_config hash in the connect
      # response, but should still be merged in as config settings to the
      # main agent configuration.
      TOP_LEVEL_KEYS = [
          "applicationId",
          "tingyunIdSecret",
          "enabled",
          "appSessionKey",
          "dataSentInterval",
          "apdex_t",
          "config"
      ]

      def self.add_top_level_keys_for_testing(add_array)
        TOP_LEVEL_KEYS.concat add_array
      end

      def self.remove_top_level_keys_for_testing(remove_arry)
        remove_arry.each{|i| TOP_LEVEL_KEYS.delete(i)}
      end

      def initialize(connect_reply)
        merged_settings = {}

        merge_top_level_keys(merged_settings, connect_reply)
        merge_agent_config_hash(merged_settings, connect_reply)
        filter_keys(merged_settings)
        # apply_feature_gates(merged_settings, connect_reply, existing_config)

        # The value under this key is a hash mapping transaction name strings
        # to apdex_t values. We don't want the nested hash to be flattened
        # as part of the call to super below, so it skips going through
        # merged_settings.
        # self[:web_transactions_apdex] = connect_reply['web_transactions_apdex']

        # This causes keys in merged_settings to be symbolized and flattened
        super(merged_settings)
      end

      def merge_top_level_keys(merged_settings, connect_reply)
        TOP_LEVEL_KEYS.each do |key_name|
          if connect_reply[key_name]
            merged_settings[key_name] = connect_reply[key_name]
          end
        end
      end

      def merge_agent_config_hash(merged_settings, connect_reply)
        if connect_reply['config']
          merged_settings.merge!(connect_reply['config'])
        end
      end

      def fix_transaction_threshold(merged_settings)
        # when value is "apdex_f" remove the config and defer to default
        if merged_settings['transaction_tracer.transaction_threshold'] =~ /apdex_f/i
          merged_settings.delete('transaction_tracer.transaction_threshold')
        end
      end

      def filter_keys(merged_settings)
        merged_settings.delete_if do |key, _|
          setting_spec = DEFAULTS[key.to_sym]
          if setting_spec
            if setting_spec[:allowed_from_server]
              false # it's allowed, so don't delete it
            else
              TingYun::Agent.logger.warn("Ignoring server-sent config for '#{key}' - this setting cannot be set from the server")
              true # delete it
            end
          else
            TingYun::Agent.logger.debug("Ignoring unrecognized config key from server: '#{key}'")
            true
          end
        end
      end

    end
  end
end
