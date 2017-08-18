# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/agent/collector/middle_ware_collector/sampler'
require 'ting_yun/support/system_info'

module TingYun
  module Agent
    module Collector
      class MemorySampler < ::TingYun::Agent::Collector::Sampler
        named :memory

        attr_accessor :sampler

        def initialize
          # macos, linux, solaris
          if platform =~ /linux/
            @sampler = ProcStatus.new
            if !@sampler.can_run?
              ::TingYun::Agent.logger.debug "Error attempting to use /proc/#{$$}/status file for reading memory. Using ps command instead."
              @sampler = ShellPS.new("ps -o rsz")
            else
              ::TingYun::Agent.logger.debug "Using /proc/#{$$}/status for reading process memory."
            end
          elsif platform =~ /darwin9/ # 10.5
            @sampler = ShellPS.new("ps -o rsz")
          elsif platform =~ /darwin1\d+/ # >= 10.6
            @sampler = ShellPS.new("ps -o rss")
          elsif platform =~ /freebsd/
            @sampler = ShellPS.new("ps -o rss")
          elsif platform =~ /solaris/
            @sampler = ShellPS.new("/usr/bin/ps -o rss -p")
          end

          raise Unsupported, "Unsupported platform for getting memory: #{platform}" if @sampler.nil?
          raise Unsupported, "Unable to run #{@sampler}" unless @sampler.can_run?
        end

        def self.supported_on_this_platform?
          platform =~ /linux|darwin|freebsd|solaris/
        end

        def platform
          TingYun::Support::SystemInfo.ruby_os_identifier.downcase
        end

        def self.platform
          TingYun::Support::SystemInfo.ruby_os_identifier.downcase
        end

        def poll
          sample = @sampler.get_sample
          if sample
            TingYun::Agent.record_metric("Memory/NULL/PhysicalUsed", sample)
          end
        end

        class Base
          def initialize
            @broken = false
          end

          def can_run?
            return false if @broken
            m = get_memory rescue nil
            m && m > 0
          end

          def get_memory
            raise 'Implement in the subclass'
          end

          def get_sample
            return nil if @broken
            begin
              m = get_memory
              if m.nil?
                ::TingYun::Agent.logger.warn "Unable to get the resident memory for process #{$$}.  Disabling memory sampler."
                @broken = true
              end
              return m
            rescue => e
              ::TingYun::Agent.logger.warn "Unable to get the resident memory for process #{$$}. Disabling memory sampler.", e
              @broken = true
              return nil
            end
          end
        end

        class ShellPS < Base
          def initialize(command)
            super()
            @command = command
          end

          # Returns the amount of resident memory this process is using in MB
          #
          def get_memory
            process = $$
            memory = `#{@command} #{process}`.split("\n")[1].to_f / 1024.0 rescue nil
            # if for some reason the ps command doesn't work on the resident os,
            # then don't execute it any more.
            raise "Faulty command: `#{@command} #{process}`" if memory.nil? || memory <= 0
            memory
          end

          def to_s
            "shell command sampler: #{@command}"
          end
        end

        # ProcStatus
        #
        # A class that samples memory by reading the file /proc/$$/status, which is specific to linux
        #
        class ProcStatus < Base
          # Returns the amount of resident memory this process is using in MB
          def get_memory
            proc_status = File.open(proc_status_file, "r") {|f| f.read_nonblock(4096).strip }
            if proc_status =~ /RSS:\s*(\d+) kB/i
              return $1.to_f / 1024.0
            end
            raise "Unable to find RSS in #{proc_status_file}"
          end

          def proc_status_file
            "/proc/#{$$}/status"
          end

          def to_s
            "proc status file sampler: #{proc_status_file}"
          end
        end
      end
    end
  end
end


