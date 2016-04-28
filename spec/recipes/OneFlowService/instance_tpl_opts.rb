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

one_flow_service 'test_instance_template_options' do
  template 'test_simple_instance_tpl'
  template_options :name => 'gary',
                   :deployment => 'none',
                   :roles => [
                     {
                       :name => 'gary_ubuntu',
                       :delete_role => true
                     },
                     {
                       :name => 'gary_ubuntu_new',
                       :vm_template => 'OpenNebula-test-tpl-strings'
                     }
                   ]
  action :instantiate
end
