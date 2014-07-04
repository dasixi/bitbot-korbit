Gem::Specification.new do |s|
  s.name        = 'bitbot-korbit'
  s.version     = '0.0.1'
  s.summary     = "A bitbot adapter for korbit"
  s.description = "A bitbot adapter for korbit"
  s.authors     = ["tomlion"]
  s.email       = 'qycpublic@gmail.com'
  s.license     = 'MIT'
  s.files       = `git ls-files`.split("\n")
  s.homepage    = 'https://github.com/peatio/bitbot-korbit'
  s.add_dependency 'korbit'
  s.add_dependency 'bitbot'
end
