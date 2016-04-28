# Copyright 2016, BlackBerry Limited
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
require 'support/opennebula_support'
require 'fileutils'
require_relative 'config.rb'

def idempotency_helper(context, recipe, expected = nil)
  context context do
    it { is_expected.to converge_test_recipe(:recipe => recipe, :expected => expected, :fail_if => '(up to date)') }
  end
  context "[SKIP] #{context}" do
    it { is_expected.to converge_test_recipe(:recipe => recipe, :expected => '(up to date)', :fail_if => nil) }
  end
end

def cleanup
  # OneDriver deletes are listed explicitly because they need to be run in a certain order.
  cleanup_list = %w(
    OneDriver/delete/OpenNebula-test-tpl-strings.rb
    OneDriver/delete/OpenNebula-test-tpl-ints.rb
    OneDriver/delete/OpenNebula-test-tpl-mix.rb
    OneDriver/delete/OpenNebula-test-vm.rb
    OneDriver/delete/OpenNebula-test-vm-vnet.rb
    OneDriver/delete/OpenNebula-test-vnet.rb
    OneDriver/delete/OpenNebula-test-img.rb
    OneDriver/delete/OpenNebula-test-snap-img.rb
  ).map { |f| "#{File.dirname(__FILE__)}/recipes/" + f }
  cleanup_list += Dir["#{File.dirname(__FILE__)}/recipes/OneFlowTemplate/delete/*.rb"] unless ONE_FLOW_URL.nil?
  cleanup_list += Dir["#{File.dirname(__FILE__)}/recipes/OneFlowService/delete/*.rb"] unless ONE_FLOW_URL.nil?
  err = get_error(chef_run(cleanup_list, false), 'Chef Client finished', nil)
  fail "\n\nTest suite cleanup failed\n#{err.first}\n\n" unless err.first.nil?
end

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.add_setting :log_dir, :default => "test-results/#{Time.now.strftime('%Y%m%d_%H%M%S')}"
  config.before(:suite) do
    FileUtils.rm_rf(config.log_dir)
    FileUtils.mkdir_p(config.log_dir)
    FileUtils.rm_rf('nodes')
    cleanup
  end
  config.after(:suite) do
    FileUtils.rm_rf('nodes')
    cleanup
    FileUtils.rm_rf('/tmp/chef-provisioning-opennebula-rspec-recipe.rb')
  end
end
