# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'when_committed/version'

Gem::Specification.new do |gem|
  gem.name          = "when_committed"
  gem.version       = WhenCommitted::VERSION
  gem.authors       = ["Joshua Flanagan"]
  gem.email         = ["jflanagan@peopleadmin.com"]
  gem.description   = %q{Run a piece of code after the current transaction is committed}
  gem.summary       = %q{Some actions (like enqueuing a background job) should not run until
the current ActiveRecord transaction has committed. ActiveRecord defines an `#after_commit` callback,
but it run for every transaction, for every instance of a class. `#when_committed` allows you to
dynamically define a block of code that should run when the transaction is committed.}
  gem.homepage      = "https://github.com/PeopleAdmin/when_committed"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.add_dependency "activerecord", ">=5.1"
  gem.add_development_dependency "sqlite3"
  gem.add_development_dependency "rspec", "2.14.1"
end
