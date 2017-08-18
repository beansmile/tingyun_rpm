# encoding: utf-8


#
#
#@items=[{dependent => dependencies}...]
#every dependent has some dependencies
#
module TingYun
  module Support
    module LibraryDetection

      module_function

      @items = []

      def defer(&block)
        item = Dependent.new
        item.instance_eval(&block)

        if item.name
          seen_names = @items.map { |i| i.name }.compact
          if seen_names.include?(item.name)
            TingYun::Agent.logger.warn("Refusing to re-register LibraryDetection block with name '#{item.name}'")
            return @items
          end
        end

        @items << item
      end

      def detect!
        @items.each do |item|
          if item.dependencies_satisfied?
            item.execute
          end
        end
      end

      def dependency_by_name(name)
        @items.find {|i| i.name == name }
      end

      def installed?(name)
        item = dependency_by_name(name)
        item && item.executed
      end

      def items
        @items
      end

      def items=(new_items)
        @items = new_items
      end


      class Dependent
        attr_reader :dependencies
        attr_reader :executed
        attr_accessor :name

        def executed!
          @executed = true
        end

        def dependencies_satisfied?
          !executed and check_dependencies
        end

        def initialize
          @dependencies = []
          @executes = []
          @name = nil
        end

        def execute
          @executes.each do |e|
            begin
              e.call
            rescue => err
              TingYun::Agent.logger.error( "Error while installing #{self.name} instrumentation:", err )
              break
            end
          end
        ensure
          executed!
        end

        def check_dependencies
          return false unless allowed_by_config? && dependencies

          dependencies.all? do |depend|
            begin
              depend.call
            rescue => err
              TingYun::Agent.logger.error( "Error while detecting #{self.name}:", err )
              false
            end
          end
        end

        def depends_on
          @dependencies << Proc.new
        end

        def allowed_by_config?
          # If we don't have a name, can't check config so allow it
          return true if self.name.nil?

          key = "disable_#{self.name}".to_sym
          if TingYun::Agent.config[key]
            TingYun::Agent.logger.debug("Not installing #{self.name} instrumentation because of configuration #{key}")
          else
            true
          end
        end

        def named(new_name)
          self.name = new_name
        end

        def executes
          @executes << Proc.new
        end
      end
    end
  end
end