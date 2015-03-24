Gem::Specification.new do |spec|
  spec.name = 'magma-dev-ucsf-immunoprofiler'
  spec.version = '0.1'
  spec.summary = 'Magma dev gem for ucsf immunoprofiler'
  spec.description = 'See summary'
  spec.email = 'Saurabh.Asthana@ucsf.edu'
  spec.homepage = 'http://magma-dev.ucsf-immunoprofiler.org/gem'
  spec.author = 'Saurabh Asthana'
  spec.files = Dir['lib/**/*.rb']
  spec.platform = Gem::Platform::RUBY
  spec.require_paths = [ 'lib' ]
  spec.add_dependency 'sequel'
  spec.add_dependency 'extlib'
end
