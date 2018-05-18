require 'ting_yun/instrumentation/support/parameter_filtering'

module TingYun
  module Instrumentation
    module Support
      module SplitController
        attr_accessor :rule, :tingyun_http_verb
        HTTP = {
          'GET' => 1,
          'POST' => 2,
          'PUT' => 3,
          'DELETE' => 4,
          'HEAD' => 5,
          'PATCH' => 3
        }

        RULE = {
          0=> :any,
          1=> :eql?,
          2=> :start_with?,
          3=> :end_with?,
          4=> :include?,
          5=> :match
        }

        def find_rule(method, path, header, params)
          @tingyun_http_verb = method
          @rule = rules.detect do |_r|
            method_match?(method, _r["match"]["method"]) and
                url_match?(path, _r["match"]["match"], _r["match"]["value"]) and
                params_match?(header, dot_flattened(params), _r["match"]["params"])
          end
        end

        def namespace
          @rule["name"]
        end

        def rules
          require 'ting_yun/support/serialize/json_wrapper'
          TingYun::Support::Serialize::JSONWrapper.load(TingYun::Agent.config[:'nbs.naming.rules'])
        end

        def method_match?(method, _r)
          _r == 0 || _r == HTTP[method]
        end

        def url_match?(url, _r, value)
          (!value.nil?) and (!value.strip.empty? rescue true) and url.send(RULE[_r], value.downcase)
        end

        def params_match?(header, params, _rs)
          return true if _rs.empty?
          begin
            _rs.each do |_r|
              next if _r["name"].nil? || _r["name"].strip.empty?
              if _r["type"] == 2
                raise_error(header["HTTP_#{_r["name"].upcase}"], RULE[_r["match"]], _r["value"], _r["type"])
              else
                raise_error(params[_r["name"].downcase], RULE[_r["match"]], _r["value"],  _r["type"])
              end
            end
          rescue
            return false
          end
          return true
        end

        def raise_error(_v, _r, _v2, _t)
          raise 'this param unexist so the rule is unmatched' if _v.nil? or _v2.nil? or _v2.strip.empty? rescue false
          return if _v && _r==:any
          unless _t == 0
            raise 'this param  is unmatched  with the rule' unless _v.send(_r, _v2)
          end
        end


        def name(path, header, params, cookie)
          return nil if @rule.nil?

          name = ""
          name << split_url(path.split('/'))
          name << "?"
          name << split_params(@rule["split"]["urlParams"], params)
          name << split_header(@rule["split"]["headerParams"], header)
          name << split_params(@rule["split"]["bodyParams"], params)
          name << split_params(@rule["split"]["cookieParams"], cookie)
          name = name[0..-2] << split_method
          name.strip
        end

        def split_url(url)
          uri = @rule["split"]["uri"]
          return '' if uri.nil? or uri.strip.empty?
          if uri.include? ','
            _i = uri.split(',').map{|n|n.to_i}
            url.values_at(*_i).join('/')
          else
            _i = uri.to_i
            if _i > 0
              url.values_at(1.._i).join('/')
            else
              url.values_at(_i..-1).join('/')
            end
          end
        end

        def split_method
           if @rule["split"]["method"]
             "(#{tingyun_http_verb})"
           else
             ''
           end
        end

        def split_params(_r, params)
          return '' if _r.nil? or _r.strip.empty?
          query_string =''
          _r.split(',').each {|_i|query_string +="#{_i}=#{params[_i]}&"}
          query_string
        end

        def split_header(_r, header)
          return '' if _r.nil? or _r.strip.empty?
          query_string =''
          _r.split(',').each {|_i|query_string +="#{_i}=#{header["HTTP_#{_i.upcase}"]}&"}
          query_string
        end

        # turns {'a' => {'b' => 'c'}} into {'b' => 'c'}
        def dot_flattened(nested_hash, result={})
          TingYun::Instrumentation::Support::ParameterFiltering.dot_flattened(nested_hash, result={})
        end
      end
    end
  end
end