# -*- ruby -*-

Gem::Specification.new do |gem|
  gem.name          = 'activerecord-tableless'
  gem.version       = "1.3.5"
  gem.platform      = Gem::Platform::RUBY
  gem.authors       = ["Jarl Friis", "Kenneth Kalmer", "Michal Zima"]
  gem.email         = ["jarl@softace.dk"]
  gem.homepage      = "https://github.com/softace/activerecord-tableless"
  gem.summary       = %q{A library for implementing tableless ActiveRecord models}
  gem.description   = %q{ActiveRecord Tableless Models provides a simple mixin for creating models that are not bound to the database. This approach is useful for taking advantage of the features of ActiveRecord such as validation, relationships, etc.}
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.has_rdoc      = true

  gem.require_paths = ["lib"]

  gem.add_runtime_dependency("activerecord", ">= 2.3.0")

  gem.add_development_dependency('bundler', '> 0')
  gem.add_development_dependency('rake', '> 0')

  #  gem.add_development_dependency("rails") # This is in the appraisal gemfiles
  gem.add_development_dependency('sqlite3', '~> 1.3')

  gem.add_development_dependency('appraisal', '~> 1.0')
  gem.add_development_dependency('cucumber', '~> 1.1')
  gem.add_development_dependency("rspec", '~> 3.1')
  gem.add_development_dependency("rspec-collection_matchers", '~> 1.0')
  gem.add_development_dependency('aruba', '>= 0.5')

  ##Specifying upper limit version for ruby 1.8.7
  gem.add_development_dependency('nokogiri', '< 1.6')
  gem.add_development_dependency('capybara', '< 2.1')

#  gem.add_development_dependency('launchy', '~> 2.1')
#  gem.add_development_dependency('debugger')
end
