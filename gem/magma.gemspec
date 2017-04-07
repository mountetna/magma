Gem::Specification.new do |spec|
  spec.name = 'magma'
  spec.version = '0.4'
  spec.summary = 'Magma client gem'
  spec.description = 'See summary'
  spec.email = 'Saurabh.Asthana@ucsf.edu'
  spec.homepage = 'http://github.com/mountetna/magma/'
  spec.author = 'Saurabh Asthana'
  spec.files = Dir['lib/**/*.rb']
  spec.platform = Gem::Platform::RUBY
  spec.require_paths = [ 'lib' ]
  spec.add_dependency 'net-http-persistent'
  spec.add_dependency 'multipart-post'
end
