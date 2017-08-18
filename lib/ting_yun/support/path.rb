# encoding: utf-8

module TingYun
  module Support
    module Path
      # The root directory for the plugin or gem
      def self.ting_yun_root
        File.expand_path(File.join("..", "..", "..",".."), __FILE__)
      end

    end
  end
end
