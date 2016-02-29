# Copyright 2016, BlackBerry, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'chef/dsl/recipe'
require 'chef/mixin/shell_out'
require 'chef/platform'
require 'chef/provisioning'
require 'chef/provisioning/opennebula_driver'
require 'chef/run_context'
require 'cheffish/rspec/matchers'
require 'opennebula'
require 'support/opennebula_support'
require 'fileutils'

def test_helper(context, recipe, expected, error = nil)
  context context do
    it { is_expected.to converge_test_recipe(recipe, expected, error) }
  end
  context "[SKIP] #{context}" do
    it { is_expected.to converge_test_recipe(recipe, :idempotent, error) }
  end
end

def cleanup
  chef_run(%w(
    OneDriver/delete/OpenNebula-test-tpl.rb
    OneDriver/delete/OpenNebula-test-tpl-ints.rb
    OneDriver/delete/OpenNebula-tpl-1-vm.rb
    OneDriver/delete/OpenNebula-bootstrap-vm.rb
    OneDriver/delete/OpenNebula-bootstrap-img.rb
    OneDriver/delete/OpenNebula-back-1-vm.rb
    OneDriver/delete/OpenNebula-back-2-vm.rb
    OneDriver/delete/OpenNebula-snap-1-img.rb
    OneDriver/delete/OpenNebula-snap-2-img.rb
  ))
end

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.add_setting :log_dir, :default => "test-results/#{Time.now.strftime('%Y%m%d_%H%M%S')}"
  config.before(:suite) do
    FileUtils.rm_rf(config.log_dir)
    FileUtils.mkdir_p(config.log_dir)
    FileUtils.rm_rf('nodes')
    fail 'Quick cleanup before testing failed.' unless cleanup.include?('Chef Client finished')
  end
  config.after(:suite) do
    FileUtils.rm_rf('nodes')
    fail 'Quick cleanup after testing failed.' unless cleanup.include?('Chef Client finished')
  end
end
