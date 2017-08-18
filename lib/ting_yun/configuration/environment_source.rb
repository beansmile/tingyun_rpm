# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require 'ting_yun/configuration/dotted_hash'


module TingYun
  module Configuration
    class EnvironmentSource < DottedHash
      SUPPORTED_PREFIXES = /^ting_yun_|^tingyun_/i
      SPECIAL_CASE_KEYS = [
          'TING_YUN_ENV',
          'TING_YUN_LOG' # read by set_log_file
      ]

      attr_accessor :alias_map, :type_map

      def initialize
        set_config_file
        set_log_file

        @alias_map = {}
        @type_map = {}

        DEFAULTS.each do |config_setting, value|
          self.type_map[config_setting] = value[:type]
          set_aliases(config_setting, value)
        end

        set_values_from_ting_yun_environment_variables
      end

      def set_aliases(config_setting, value)
        set_dotted_alias(config_setting)

        return unless value[:aliases]
        value[:aliases].each do |alise|
          self.alias_map[alise] = config_setting
        end
      end

      def set_dotted_alias(original_config_setting)
        config_setting = original_config_setting.to_s


        if config_setting.include? '.'
          config_alias = config_setting.gsub(/\./, '_').to_sym
          self.alias_map[config_alias] = original_config_setting
        end
      end

      def set_config_file
        self[:config_path] = ENV['NRCONFIG'] if ENV['NRCONFIG']
      end


      def set_log_file
        if ENV['TING_YUN_LOG']
          if ENV['TING_YUN_LOG'].upcase == 'STDOUT'
            self[:log_file_path] = self[:log_file_name] = 'STDOUT'
          else
            self[:log_file_path] = File.dirname(ENV['TING_YUN_LOG'])
            self[:log_file_name] = File.basename(ENV['TING_YUN_LOG'])
          end
        end
      end

      def set_values_from_ting_yun_environment_variables
        env_var_keys = collect_ting_yun_environment_variable_keys
        env_var_keys.each do |key|
          next if SPECIAL_CASE_KEYS.include?(key.upcase)
          set_value_from_environment_variable(key)
        end
      end

      def set_value_from_environment_variable(key)
        config_key = convert_environment_key_to_config_key(key)
        set_key_by_type(config_key, key)
      end

      def set_key_by_type(config_key, environment_key)
        value = ENV[environment_key]
        type = self.type_map[config_key]

        if type == String
          self[config_key] = value
        elsif type == Fixnum
          self[config_key] = value.to_i
        elsif type == Float
          self[config_key] = value.to_f
        elsif type == Symbol
          self[config_key] = value.to_sym
        elsif type == TingYun::Configuration::Boolean
          if value =~ /false|off|no/i
            self[config_key] = false
          elsif value != nil
            self[config_key] = true
          end
        else
          # TingYun::Agent.logger.info("#{environment_key} does not have a corresponding configuration setting (#{config_key} does not exist).")
          self[config_key] = value
        end

      end

      def convert_environment_key_to_config_key(key)
        stripped_key = key.gsub(SUPPORTED_PREFIXES, '').downcase.to_sym
        self.alias_map[stripped_key] || stripped_key
      end

      def collect_ting_yun_environment_variable_keys
        ENV.keys.select { |key| key.match(SUPPORTED_PREFIXES) }
      end
    end
  end
end