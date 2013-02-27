require 'rake'

Gem::Specification.new do |s|
  s.name      = 'lc3spec'
  s.version   = '0.0.0'
  s.date      = '2013-02-27'
  s.summary   = 'Testing and grading suite for LC-3 assembly programs'
  s.authors   = ['Chun Yang']
  s.email     = 'x@cyang.info'
  s.files     = FileList['lib/**/*.rb',
                         'bin/*',
                         '[A-Z]*',
                         'test/**/*'].to_a
  s.homepage  = 'http://github.com/chunyang/lc3spec'
end
