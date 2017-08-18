# encoding: utf-8

require 'ting_yun/frameworks/rails3'

module TingYun
  module Frameworks
    class Rails4 < TingYun::Frameworks::Rails3

      def rails_gem_list
        Bundler.rubygems.all_specs.map { |gem| "#{gem.name} (#{gem.version})" }
      end
    end
  end
end