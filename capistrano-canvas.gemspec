# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = "capistrano-canvas"
  gem.version       = '1.0.0'
  gem.authors       = ["Graham Ballantyne"]
  gem.email         = ["grahamb@sfu.ca"]
  gem.description   = %q{canvas-lms deploy tasks for Capistrano}
  gem.summary       = %q{canvas-lms deploy tasks for Capistrano}
  gem.homepage      = "https://github.com/grahamb/capistrano-canvas"

  gem.files         = `git ls-files`.split($/)
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'capistrano', '~> 3.1'
end
