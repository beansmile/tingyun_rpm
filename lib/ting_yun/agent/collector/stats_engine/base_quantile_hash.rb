module TingYun
  module Agent
    module Collector
      class BaseQuantileHash
        attr_reader :hash

        def initialize
          @hash = {}
        end

        def merge!(hash)
          hash.each do |name, time|
            @hash[name] ||= []
            @hash[name] << time
          end
        end
      end
    end
  end
end
