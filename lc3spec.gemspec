require 'rake'

Gem::Specification.new do |s|
  s.name        = 'lc3spec'
  s.version     = '0.1.4'
  s.date        = '2013-02-27'
  s.summary     = 'Testing and grading suite for LC-3 assembly programs'
  s.description = 'DSL for testing LC-3 assembly programs'
  s.authors     = ['Chun Yang']
  s.email       = 'x@cyang.info'
  s.files       = FileList['lib/**/*.rb',
                           'bin/*',
                           '[A-Z]*',
                           'test/**/*'].to_a
  s.executables = 'lc3spec'
  s.homepage    = 'http://github.com/chunyang/lc3spec'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 1.9.3'
  s.add_development_dependency 'rspec', '~> 2.0'
end
