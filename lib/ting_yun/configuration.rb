# encoding: utf-8
# This file is distributed under Ting Yun's license terms.


module TingYun
  module Configuration

    def self.get_name
      app_name = TingYun::Agent.config[:app_name]
      case app_name
        when Array then
          app_name
        when String then
          app_name.split(';')
        else
          []
      end
    end
  end
end