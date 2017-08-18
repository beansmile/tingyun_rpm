# encoding: utf-8

# A Hash-like class for storing errorTraceData data.
#

require 'ting_yun/support/exception'
require 'ting_yun/support/coerce'


module TingYun
  module Agent
    module Collector
      class NoticedError



        attr_accessor :metric_name, :timestamp, :message, :exception_class_name,
                      :stack_trace, :attributes_from_notice_error, :attributes,
                      :count_error, :is_external_error, :external_metric_name, :code, :trace

        attr_reader :exception_id, :is_internal


        def initialize(metric_name, exception, timestamp = Time.now)
          @metric_name = metric_name
          @timestamp = timestamp
          @stack_trace = []
          @count_error = 1
          @exception_id = exception.object_id
          @exception_class_name = exception.is_a?(Exception) ? exception.class.name : 'Error'
          @is_external_error = exception.respond_to?(:tingyun_external)? exception.tingyun_external : false
          if @is_external_error
            @external_metric_name = exception.tingyun_klass
            @code = exception.tingyun_code
            @trace = exception.tingyun_trace
          end
          # It's critical that we not hold onto the exception class constant in this
          # class. These objects get serialized for Resque to a process that might
          # not have the original exception class loaded, so do all processing now
          # while we have the actual exception!
          @is_internal = (exception.class < TingYun::Support::Exception::InternalAgentError)

          if exception.nil?
            @message = '<no message>'
          elsif exception.respond_to?('original_exception')
            @message = (exception.original_exception || exception).to_s
          else # exception is not nil, but does not respond to original_exception
            @message = exception.to_s
          end


          unless @message.is_a?(String)
            # In pre-1.9.3, Exception.new({}).to_s.class != String
            # That is, Exception#to_s may not return a String instance if one wasn't
            # passed in upon creation of the Exception. So, try to generate a useful
            # String representation of the exception message, falling back to failsafe
            @message = String(@message.inspect) rescue '<unknown message type>'
          end

          # clamp long messages to 4k so that we don't send a lot of
          # overhead across the wire
          @message = @message[0..4095] if @message.length > 4096
        end


        def ==(other)
          return true if other.respond_to?(:exception_id) && exception_id == other.exception_id

          if metric_name == other.metric_name && message == other.message
            @count_error = count_error + 1
            return true
          else
            return false
          end
        end

        include TingYun::Support::Coerce

        def to_collector_array(encoder)
          if  is_external_error
            [timestamp.to_i,
             string(external_metric_name),
             int(code),
             string(exception_class_name),
             count_error,
             string(metric_name),
             encoder.encode(error_params)
            ]
          else
            [timestamp.to_i,
             string(metric_name),
             int(attributes.agent_attributes[:httpStatus]),
             string(exception_class_name),
             string(message),
             count_error,
             string(attributes.agent_attributes[:request_path]||metric_name),
             encoder.encode(error_params)
            ]
          end
        end

        def error_params
          hash = {
              :params => custom_params
          }
          if is_external_error
            hash[:stacktrace] = trace
          else
            hash[:stacktrace] = stack_trace
            hash[:requestParams] = request_params
          end
          hash
        end

        def custom_params
          hash = {:threadName => string(attributes.agent_attributes[:threadName])}
          if is_external_error
            hash[:httpStatus] = int(code)
          else
            hash[:httpStatus] = int(attributes.agent_attributes[:httpStatus])
            hash[:referer] = string(attributes.agent_attributes[:referer]) || ''
          end
          hash
        end

        def request_params
          return {}  unless TingYun::Agent.config['nbs.capture_params']
          attributes.request_params
        end

      end
    end
  end
end

