require 'rake'

Gem::Specification.new do |s|
  s.name = "debloy"
  s.summary = "Deploying debian packages with capistrano"
  s.description = "See http://jeroenr.github.com/debloy/"
  s.version = "1.3.1"
  s.authors = ["Jeroen Rosenberg"]
  s.email = ["jeroen.rosenberg@gmail.com"]
  s.homepage = "http://github.com/jeroenr/debloy"
  s.files = FileList["README.md", "Rakefile", "lib/**/*.rb"]
end
