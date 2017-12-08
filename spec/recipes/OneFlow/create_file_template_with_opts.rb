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

one_flow_template 'RSpec-flow-file-template-with-opts' do
  template 'file:///tmp/RSpec-flow-file-template-with-opts.json'
  template_options :deployment => 'none',
                   :ready_status_gate => false,
                   :roles => [
                     {
                       :name => 'RSpecTest',
                       :delete_role => true
                     },
                     {
                       :name => 'RSpecRetest',
                       :vm_template => 'RSpec-test-template',
                       :cooldown => 2
                     }
                   ]
  mode '640'
  action :create
end
