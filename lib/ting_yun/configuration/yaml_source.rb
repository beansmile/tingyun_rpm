# encoding: utf-8
require 'ting_yun/configuration/dotted_hash'
require 'ting_yun/support/language_support'
require 'erb'
require 'yaml'

module TingYun
  module Configuration
    class YamlSource < DottedHash
      attr_accessor :file_path, :failures

      def initialize(path, env)
        config = {}
        @failures = []

        begin
          @file_path = vaildate_config_file_path(path)
          return unless @file_path

          ::TingYun::Agent.logger.info("Reading configuration from #{path} (#{Dir.pwd})")

          raw_file = File.read(@file_path)
          erb_file = process_erb(raw_file)
          config = process_yaml(erb_file, env, config, @file_path)
        rescue ScriptError, StandardError => e
          log_failure("Failed to read or parse configuration file at #{path}", e)
        end
        booleanify_values(config, 'nbs.agent_enabled', 'enabled')
        super(config, true)
      end

      def failed?
        !@failures.empty?
      end

      protected

      def vaildate_config_file_path(path)
        expanded_path = File.expand_path(path)

        if path.empty? || !File.exist?(expanded_path)
          warn_missing_config_file(expanded_path)
          return
        end
        expanded_path
      end

      def warn_missing_config_file(path)
        based_on = 'unknown'
        source = ::TingYun::Agent.config.source(:config_path)
        candidate_paths = [path]

        case source
          when DefaultSource
            based_on = "default"
            candidate_paths = TingYun::Agent.config[:config_search_paths].map do |p|
              File.expand_path(p)
            end
          when EnvironmentSource
            based_on = "environment_source"
          when ManualSource
            based_on = 'API call'
        end

        TingYun::Agent.logger.warn(
            "No configuration file found. Working directory = #{Dir.pwd}",
            "Looked in these locations (based on #{based_on}): #{candidate_paths.join(", ")}"
        )
      end

      def process_erb(file)
        begin
          # Exclude lines that are commented out so failing Ruby code in an
          # ERB template commented at the YML level is fine. Leave the line,
          # though, so ERB line numbers remain correct.
          file.gsub!(/^\s*#.*$/, '#')

          # Next two are for populating the tingyun.yml via erb binding, necessary
          # when using the default tingyun.yml file
          generated_for_user = ''
          license_key = ''

          ERB.new(file).result(binding)
        rescue ScriptError, StandardError => e
          log_failure("Failed ERB processing configuration file. This is typically caused by a Ruby error in <% %> templating blocks in your tingyun.yml file.", e)
          nil
        ensure
          # Avoid warnings by using these again
          generated_for_user = nil
          license_key = nil
        end
      end

      def process_yaml(file, env, config, path)
        if file
          confighash = with_yaml_engine { YAML.load(file) }
          unless confighash.key?(env)
            log_failure("Config file at #{path} doesn't include a '#{env}' section!")
          end

          config = confighash[env] || {}
        end
        config
      end

      def with_yaml_engine
        return yield unless TingYun::Support::LanguageSupport.needs_syck?

        yamler = ::YAML::ENGINE.yamler
        ::YAML::ENGINE.yamler = 'syck'
        result = yield
        ::YAML::ENGINE.yamler = yamler
        result
      end

      def booleanify_values(config, *keys)
        # auto means defer ro default
        keys.each do |option|
          if config[option] == 'auto'
            config.delete(option)
          elsif !config[option].nil? && !is_boolean?(config[option])
            config[option] = !!(config[option] =~ /yes|on|true/i)
          end
        end
      end

      def is_boolean?(value)
        value == !!value
      end

      def log_failure(*messages)
        ::TingYun::Agent.logger.error(*messages)
        @failures << messages
      end
    end
  end
end