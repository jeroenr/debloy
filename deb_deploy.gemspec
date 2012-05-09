require 'rake'

Gem::Specification.new do |s|
  s.name = "deb_deploy"
  s.summary = "Deploying debian packages with capistrano"
  s.description = "See http://github.com/jeroenr/deb_deploy"
  s.version = "1.1.5"
  s.authors = ["Jeroen Rosenberg"]
  s.email = ["jeroen.rosenberg@gmail.com"]
  s.homepage = "http://github.com/jeroenr/deb_deploy"
  s.files = FileList["README.md", "Rakefile", "lib/**/*.rb"]
end
