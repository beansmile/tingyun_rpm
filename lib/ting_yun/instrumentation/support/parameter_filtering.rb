# encoding: utf-8



module TingYun
  module Instrumentation
    module Support
      module ParameterFiltering

        module_function

        def filter_rails_request_parameters(params)
          result = params.dup
          result.delete("controller")
          result.delete("action")
          result.delete("commit")
          result.delete("authenticity_token")
          result.delete_if{|_,v| !v.is_a? String}
          TingYun::Agent.config["nbs.ignored_params"].split(',').each{|key| result.delete(key)}
          result
        end

        # turns {'a' => {'b' => 'c'}} into {'b' => 'c'}
        def dot_flattened(nested_hash, result={})
          nested_hash.each do |key, val|
            next if val == nil
            if val.respond_to?(:has_key?)
              dot_flattened(val, result)
            else
              result[key] = val
            end
          end
          result
        end

        def flattened_filter_request_parameters(params)
          filter_rails_request_parameters(dot_flattened(params))
        end
      end
    end
  end
end
