# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/agent'
require 'ting_yun/support/exception'

module TingYun
  module Support
    module Serialize
      class Marshaller
        def prepare(data, options={})
          encoder = options[:encoder] || default_encoder
          if data.respond_to?(:to_collector_array)
            data.to_collector_array(encoder)
          elsif data.kind_of?(Array)
            data.map { |element| prepare(element, options) }
          elsif data.kind_of?(Hash)
            data.each {|_k,_v| data[_k]=prepare(_v, options)}
          else
            data
          end
        end

        def default_encoder
          Encoders::Identity
        end

        def self.human_readable?
          false
        end

        def return_value_for_testing(data)
          return_value(data)
        end

        protected

        def return_value(data)
          if data.respond_to?(:has_key?) && data.has_key?('status') 
            if data['status'] =="error"
              raise TingYun::Support::Exception::UnKnownServerException.new("sorry，the application is unable to use the tingyun service now, we should reconnect again ")
            else
              return data['result']
            end
          else
            raise TingYun::Support::Exception::UnKnownServerException.new("sorry，the application is unable to use the tingyun service now, we should reconnect again ")
          end
        end
      end
    end
  end
end
