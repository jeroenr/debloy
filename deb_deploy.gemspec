require 'rake'

Gem::Specification.new do |s|
  s.name = "deb_deploy"
  s.summary = "Masterless puppet with capistrano"
  s.description = "See http://github.com/jeroenr/deb_deploy"
  s.version = "0.9.0"
  s.authors = ["Jeroen Rosenberg"]
  s.email = ["jeroen.rosenberg@gmail.com"]
  s.homepage = "http://github.com/jeroenr/deb_deploy"
  s.files = FileList["README.md", "Rakefile", "lib/**/*.rb"]
end