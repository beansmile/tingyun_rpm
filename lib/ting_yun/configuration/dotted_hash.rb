# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

module TingYun
  module Configuration
    class DottedHash < ::Hash

      def self.symbolize(hash)
        hash.keys.each do |key|
          hash[key.to_sym] = hash.delete(key)
        end
      end

      def initialize(hash, keep_nesting = false)
        self.merge!(hash) if keep_nesting
        self.merge!(dot_flattened(hash))

        DottedHash.symbolize(self)
      end

      def inspect
        "#<#{self.class.name}:#{object_id} #{super}>"
      end

      def to_hash
        {}.replace(self)
      end

      protected

      # turns {'a' => {'b' => 'c'}} into {'a.b' => 'c'}
      def dot_flattened(nested_hash, names=[], result={})
        nested_hash.each do |key, val|
          next if val == nil
          if val.respond_to?(:has_key?)
            dot_flattened(val, names + [key], result)
          else
            result[(names + [key]).join('.')] = val
          end
        end
        result
      end
    end

  end
end
