require File.expand_path('../lib/linkify-it-rb/version.rb', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = 'linkify-it-rb'
  gem.version       = LinkifyIt::VERSION
  gem.authors       = ["Brett Walker", "Vitaly Puzrin"]
  gem.email         = 'github@digitalmoksha.com'
  gem.summary       = "linkify-it for motion-markdown-it in Ruby"
  gem.description   = "Ruby version of linkify-it for motion-markdown-it, for Ruby and RubyMotion"
  gem.homepage      = 'https://github.com/digitalmoksha/linkify-it-rb'
  gem.licenses      = ['MIT']

  gem.files         = Dir.glob('lib/**/*.rb')
  gem.files        << 'README.md'
  gem.test_files    = Dir.glob('spec/**/*.rb')

  gem.require_paths = ["lib"]

  gem.add_dependency 'uc.micro-rb', '~> 1.0'
end