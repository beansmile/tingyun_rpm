# encoding: utf-8

module TingYun
  module Support
    module Hostname

      def self.get
        Socket.gethostname
      end

    end
  end
end
