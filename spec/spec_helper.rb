require 'chef/dsl/recipe'
require 'chef/mixin/shell_out'
require 'chef/platform'
require 'chef/provisioning'
require 'chef/provisioning/opennebula_driver'
require 'chef/run_context'
require 'cheffish/rspec/matchers'
require 'opennebula'
require 'support/opennebula_support'

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.before(:suite) do
    Dir.mkdir("test-results") unless Dir.exists?("test-results")
    Dir.glob("test-results/*").each do |file|
      File.delete(file)
    end
    delete_all
  end
end