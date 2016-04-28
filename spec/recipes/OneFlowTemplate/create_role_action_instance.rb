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

one_flow_template 'test_role_action_instance' do
  template :roles => [
    {
      :name => 'shutdown',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'shutdown_hard',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'undeploy',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'undeploy_hard',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'hold',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'release',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'stop',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'suspend_resume',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'boot',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'delete',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'delete_recreate',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'reboot',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'reboot_hard',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'poweroff',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'poweroff_hard',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'do_not_instance',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    }
  ]
  action :create
end
