# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jsonapi_compliable/version'

Gem::Specification.new do |spec|
  spec.name          = "jsonapi_compliable"
  spec.version       = JsonapiCompliable::VERSION
  spec.authors       = ["Lee Richmond", "Venkata Pasupuleti"]
  spec.email         = ["richmolj@gmail.com", "spasupuleti4@bloomberg.net"]

  spec.summary       = %q{Easily build jsonapi.org-compatible APIs}
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'jsonapi-serializable', '~> 0.2.1'

  spec.add_development_dependency "activerecord", ['>= 4.1', '< 6']
  spec.add_development_dependency "kaminari", '~> 0.17'
  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "database_cleaner"
end
