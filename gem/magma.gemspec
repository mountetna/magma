Gem::Specification.new do |spec|
  spec.name = 'magma-dev-ucsf-immunoprofiler'
  spec.version = '0.3'
  spec.summary = 'Magma dev gem for ucsf immunoprofiler'
  spec.description = 'See summary'
  spec.email = 'Saurabh.Asthana@ucsf.edu'
  spec.homepage = 'http://magma-dev.ucsf-immunoprofiler.org/gem'
  spec.author = 'Saurabh Asthana'
  spec.files = Dir['lib/**/*.rb']
  spec.platform = Gem::Platform::RUBY
  spec.require_paths = [ 'lib' ]
  spec.add_dependency 'sequel'
  spec.add_dependency 'sequel_polymorphic', '>= 0.2.2'
  spec.add_dependency 'mini_magick'
  spec.add_dependency 'germ'
  spec.add_dependency 'net-http-persistent'
  spec.add_dependency 'extlib'
  spec.add_dependency 'carrierwave-sequel'
  spec.add_dependency 'fog'
  spec.add_dependency 'spreadsheet'
end
