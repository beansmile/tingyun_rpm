# encoding: utf-8

module TingYun
  module Logger
    module CreateLoggerHelper

      module_function

      def create_log(root, override_logger)
        if !override_logger.nil?
          @log = override_logger
        elsif ::TingYun::Agent.config[:'nbs.agent_enabled'] == false
          create_null_logger
        else
          if wants_stdout?
            @log = ::Logger.new(STDOUT)
          else
            create_log_to_file(root)
          end
        end
      end


      def check_log_file
        unless File.exist? @file_path
          begin
            @log = ::Logger.new(@file_path)
            set_log_format
            set_log_level
          rescue => e
            @log = ::Logger.new(STDOUT)
            warn("check_log_file:  Failed creating logger for file #{@file_path}, using standard out for logging.", e)
          end
        end
      end

      def create_new_logfile
        file_path = TingYun::Agent.logger.file_path
        shift_age = TingYun::Agent.config[:agent_log_file_number]
        if File.size(file_path) >= (TingYun::Agent.config[:agent_log_file_size])*1024*1024
          (shift_age-3).downto(0) do |i|
            index_file = file_path.gsub('.log', "_#{i}.log")
            if FileTest.exist?(index_file)
              File.rename(index_file, file_path.gsub('.log', "_#{i+1}.log"))
            end
          end
          TingYun::Agent.agent.untraced_graceful_disconnect
          File.rename(file_path, file_path.gsub('.log', "_0.log"))
        end
      end

      def create_log_to_file(root)
        path = find_or_create_file_path(::TingYun::Agent.config[:agent_log_file_path], root)
        unless path
          @log = ::Logger.new(STDOUT)
          warn("Error creating log directory #{::TingYun::Agent.config[:agent_log_file_path]}, using standard out for logging.")
        else
          @file_path = "#{path}/#{::TingYun::Agent.config[:agent_log_file_name]}"
          begin
            @log = ::Logger.new(@file_path)
          rescue => e
            @log = ::Logger.new(STDOUT)
            warn("Failed creating logger for file #{@file_path}, using standard out for logging.", e)
          end
        end
      end

      def create_null_logger
        @log = ::TingYun::Logger::NullLogger.new
      end


      def find_or_create_file_path(path_setting, root)
        for abs_path in [File.expand_path(path_setting),
                         File.expand_path(File.join(root, path_setting))] do
          if File.directory?(abs_path) || (FileUtils.mkdir_p(abs_path) rescue nil)
            return abs_path[%r{^(.*?)/?$}]
          end
        end
        nil
      end


    end
  end
end
