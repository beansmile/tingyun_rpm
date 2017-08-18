# encoding: utf-8

module TingYun
  module Instrumentation
    module Support
      class TransactionNamer


        def self.prefix_for_category(txn, category = nil)
          category ||= (txn && txn.category)

          case category
            when :controller then
              ::TingYun::Agent::Transaction::CONTROLLER_PREFIX
            when :task then
              ::TingYun::Agent::Transaction::TASK_PREFIX
            when :rack then
              ::TingYun::Agent::Transaction::RACK_PREFIX
            when :uri then
              ::TingYun::Agent::Transaction::CONTROLLER_PREFIX
            when :sinatra then
              ::TingYun::Agent::Transaction::CONTROLLER_PREFIX
            when :middleware then
              ::TingYun::Agent::Transaction::MIDDLEWARE_PREFIX
            when :grape then
              ::TingYun::Agent::Transaction::GRAPE_PREFIX
            when :rake then
              ::TingYun::Agent::Transaction::RAKE_PREFIX
            when :action_cable then
              ::TingYun::Agent::Transaction::CABLE_PREFIX
            else
              "#{category.to_s}/" # for internal use only
          end
        end


        def self.name_for(txn, traced_obj, category, options={})
          "#{prefix_for_category(txn, category)}#{path_name(traced_obj, options)}"
        end

        def self.path_name(traced_obj, options={})
          return options[:path] if options[:path]

          class_name = klass_name(traced_obj, options)
          if options[:name]
            if class_name
              "#{class_name}/#{options[:name]}"
            else
              options[:name]
            end
          elsif traced_obj.respond_to?(:tingyun_metric_path)
            traced_obj.tingyun_metric_path
          else
            class_name
          end
        end

        def self.klass_name(traced_obj, options={})
          return options[:class_name] if options[:class_name]

          if (traced_obj.is_a?(Class) || traced_obj.is_a?(Module))
            traced_obj.name
          else
            traced_obj.class.name
          end
        end
      end
    end
  end
end
