# encoding: utf-8

module TingYun
  module Support
    class VersionNumber

      include Comparable

      attr_reader :parts

      def initialize(version_string)
        version_string ||= '1.0.0'
        @parts = version_string.split('.').map { |n| n =~ /^\d+$/ ? n.to_i : n }
      end

      def major_version;
        @parts[0];
      end

      def minor_version;
        @parts[1];
      end

      def tiny_version;
        @parts[2];
      end

      def <=>(other)
        other = self.class.new(other) if other.is_a? String
        self.class.compare(self.parts, other.parts)
      end

      def to_s
        @parts.join(".")
      end

      def hash
        @parts.hash
      end

      def eql? other
        (self <=> other) == 0
      end

      private

      def self.compare(parts1, parts2)
        a, b = parts1.first, parts2.first
        case
          when a.nil? && b.nil? then
            0
          when a.nil? then
            b.is_a?(Fixnum) ? -1 : 1
          when b.nil? then
            -compare(parts2, parts1)
          when a.to_s == b.to_s then
            compare(parts1[1..-1], parts2[1..-1])
          when a.is_a?(String) then
            b.is_a?(Fixnum) ? -1 : (a <=> b)
          when b.is_a?(String) then
            -compare(parts2, parts1)
          else # they are both fixnums, not nil
            a <=> b
        end
      end


    end
  end
end
