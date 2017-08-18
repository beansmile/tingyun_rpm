# encoding: utf-8

require 'ting_yun/support/library_detection'

module TingYun
  module Frameworks
    # Contains methods that relate to adding and executing files that
    # contain instrumentation for the Ruby Agent

    module Instrumentation

      # Signals the agent that it's time to actually load the
      # instrumentation files. May be overridden by subclasses
      def install_instrumentation
        _install_instrumentation
      end


      def add_instrumentation(pattern)
        if @instrumented
          load_instrumentation_files pattern
        else
          @instrumentation_files << pattern
        end
      end

      # Adds a list of files in Dir.glob format
      # (e.g. '/app/foo/**/*_instrumentation.rb')
      # This requires the files within a rescue block, so that any
      # errors within instrumentation files do not affect the overall
      # agent or application in which it runs.
      def load_instrumentation_files(pattern)
        Dir.glob(pattern) do |file|
          begin
            if file.to_s.include?('instrumentation/kafka.rb')
              # (**options) will report syntax error when ruby version under 2.0.0
              require file.to_s if (defined? RUBY_VERSION) && (TingYun::Support::VersionNumber.new(RUBY_VERSION) >= TingYun::Support::VersionNumber.new('2.0.0'.freeze))
            else
              require file.to_s
            end
          rescue LoadError => e
            TingYun::Agent.logger.warn "Error loading instrumentation file '#{file}':", e
          end
        end
      end

      def detect_dependencies
        LibraryDetection.detect!
      end

      private

      def _install_instrumentation
        return if @instrumented

        # instrumentation for the key code points inside rails for monitoring by TingYun.
        # note this file is loaded only if the tingyun agent is enabled (through config/tingyun.yml)
        instrumentation_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'instrumentation'))
        @instrumentation_files << File.join(instrumentation_path, '*.rb')
        @instrumentation_files << File.join(instrumentation_path, Agent.config[:framework].to_s, '*.rb')
        @instrumentation_files.each { |pattern| load_instrumentation_files pattern }

        TingYun::Support::LibraryDetection.detect!

        ::TingYun::Agent.logger.info('Finished instrumentation')

        @instrumented = true
      end

    end
  end
end
