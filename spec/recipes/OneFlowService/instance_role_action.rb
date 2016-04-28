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

one_flow_service 'test_role_action' do
  template 'test_role_action_instance'
  template_options :roles => [
    {
      :name => 'do_not_instance',
      :delete_role => true
    },
    {
      :name => 'snapshot_create',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    },
    {
      :name => 'scale',
      :vm_template => 'OpenNebula-test-tpl-strings',
      :cooldown => 10
    }
  ]
  action :instantiate
end
