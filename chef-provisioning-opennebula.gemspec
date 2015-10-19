$:.unshift(File.dirname(__FILE__) + '/lib')
require 'chef/provisioning/opennebula_driver/version'

Gem::Specification.new do |s|
  s.name = 'chef-provisioning-opennebula'
  s.version = Chef::Provisioning::OpenNebulaDriver::VERSION
  s.license = 'All rights reserved'
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = [ 'README.md', 'LICENSE' ]
  s.summary = 'Driver for creating OpenNebula instances in Chef Provisioning.'
  s.description = s.summary
  s.authors = [ 'Andrew J. Brown', 'Bogdan Buczynski' ]
  s.email = [ 'anbrown@blackberry.com', 'bbuczynski@blackberry.com' ]
  s.homepage = 'https://gitlab.rim.net/chef/chef-provisioning-opennebula'

  s.add_dependency 'chef'
  s.add_dependency 'chef-provisioning', '> 0.15'
  s.add_dependency 'opennebula', '~> 4.10'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rake'

  s.bindir       = "bin"
  s.executables  = %w( )

  s.require_path = 'lib'
  s.files = %w(Rakefile LICENSE README.md) + Dir.glob("{distro,lib,tasks,spec}/**/*", File::FNM_DOTMATCH).reject {|f| File.directory?(f) }
end
