# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sequel/extensions/savepoint_hooks/version'

Gem::Specification.new do |spec|
  spec.name          = 'sequel-savepoint-hooks'
  spec.version       = Sequel::SavepointHooks::VERSION
  spec.authors       = ["Chris Hanks"]
  spec.email         = ['christopher.m.hanks@gmail.com']

  spec.summary       = %q{Sequel extension that allows savepoints to trigger after_commit and after_rollback hooks.}
  spec.homepage      = 'https://github.com/chanks/sequel-savepoint-hooks'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler',        '~> 1.10'
  spec.add_development_dependency 'rake',           '~> 10.0'
  spec.add_development_dependency 'minitest',       '~> 5.8.1'
  spec.add_development_dependency 'minitest-hooks', '~> 1.2.0'
  spec.add_development_dependency 'pg'

  spec.add_dependency 'sequel', '~> 5.0'
end
