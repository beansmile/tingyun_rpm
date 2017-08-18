# encoding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ting_yun/version'

Gem::Specification.new do |s|
  s.name     = 'tingyun_rpm'
  s.version  = TingYun::VERSION::STRING
  s.author   = 'tingyun'
  # s.email    = 'support@tingyun.com'
  # s.homepage = 'http://tingyun.com/features/ruby.html'

  s.licenses    = ['Tingyun', 'MIT', 'Ruby']
  s.summary     = 'TingYun Ruby Agent'
  # s.description = 'TingYun Ruby Agent. (http://tingyun.com/features/ruby.html)'

  s.required_ruby_version     = '>= 1.8.7'
  s.required_rubygems_version = '>= 1.3.5'

  file_list = `git ls-files`.split
  file_list.delete_if { |item| item =~ /(test\/|bin\/|Rakefile)/ }
  s.files = file_list

  s.require_paths = ['lib']
  s.rubygems_version = Gem::VERSION

  s.add_development_dependency 'rake', '~> 10.1.0'
  s.add_development_dependency 'minitest', '~> 4.7'
  s.add_development_dependency 'minitest-ci', '~> 2.4.0'
  s.add_development_dependency 'minitest-focus', '~> 1.1'
  s.add_development_dependency 'minitest-reporters', '0.14.24'
  s.add_development_dependency 'simplecov', '~> 0.10.0'
  s.add_development_dependency 'mocha', '~> 0.13.0'
  s.add_development_dependency 'rails', '~> 3.2'
  s.add_development_dependency 'pry', '~> 0.9.12'
  s.add_development_dependency 'hometown', '~> 0.2.5'
  s.add_development_dependency 'yard'
  s.add_development_dependency 'rubycritic'


  if RUBY_VERSION >= '1.9.3'
    s.add_development_dependency 'guard', '= 2.12.5'
    s.add_development_dependency 'guard-minitest', '= 2.4.4'
    s.add_development_dependency 'rb-fsevent', '= 0.9.4'
    s.add_development_dependency 'guard-rubycritic'
  end

  # compatible with Ruby 1.8.7
  s.add_development_dependency 'i18n', '0.6.11'

  if RUBY_PLATFORM == 'java'
    s.add_development_dependency 'activerecord-jdbcsqlite3-adapter'
    s.add_development_dependency 'jruby-openssl'
  else
    s.add_development_dependency 'sqlite3', '= 1.3.10'
  end

  if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'rbx'
    s.add_development_dependency 'rubysl'
    s.add_development_dependency 'racc'
  end
end
