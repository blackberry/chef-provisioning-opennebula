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

one_flow_template 'RSpec-role-action-template' do
  template :roles => [
    {
      :name => 'RSpec_shutdown',
      :vm_template => 'RSpec-test-template',
      :cooldown => 1
    },
    {
      :name => 'RSpec_shutdown_hard',
      :vm_template => 'RSpec-test-template',
      :cooldown => 1
    },
    {
      :name => 'RSpec_undeploy',
      :vm_template => 'RSpec-test-template',
      :cooldown => 1
    },
    {
      :name => 'RSpec_undeploy_hard',
      :vm_template => 'RSpec-test-template',
      :cooldown => 1
    },
    {
      :name => 'RSpec_hold',
      :vm_template => 'RSpec-test-template',
      :cooldown => 1
    },
    {
      :name => 'RSpec_stop',
      :vm_template => 'RSpec-test-template',
      :cooldown => 1
    },
    {
      :name => 'RSpec_suspend',
      :vm_template => 'RSpec-test-template',
      :cooldown => 1
    },
    {
      :name => 'RSpec_boot',
      :vm_template => 'RSpec-test-template',
      :cooldown => 1
    },
    {
      :name => 'RSpec_delete_recreate',
      :vm_template => 'RSpec-test-template',
      :cooldown => 1
    },
    {
      :name => 'RSpec_reboot',
      :vm_template => 'RSpec-test-template',
      :cooldown => 1
    },
    {
      :name => 'RSpec_reboot_hard',
      :vm_template => 'RSpec-test-template',
      :cooldown => 1
    },
    {
      :name => 'RSpec_poweroff',
      :vm_template => 'RSpec-test-template',
      :cooldown => 1
    },
    {
      :name => 'RSpec_poweroff_hard',
      :vm_template => 'RSpec-test-template',
      :cooldown => 1
    },
    {
      :name => 'do_not_instance',
      :vm_template => 'RSpec-test-template',
      :cooldown => 1
    }
  ]
  action :create
end
