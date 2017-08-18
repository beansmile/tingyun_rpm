# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require 'ting_yun/configuration/dotted_hash'

module TingYun
  module Configuration
    class ManualSource < DottedHash
      def initialize(hash)
        super(hash, true)
      end
    end
  end
end
