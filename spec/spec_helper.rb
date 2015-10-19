# Copyright 2015, BlackBerry, Inc.
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

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
