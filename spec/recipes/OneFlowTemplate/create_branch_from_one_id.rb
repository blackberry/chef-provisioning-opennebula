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

id = Chef::Provisioning::OpenNebulaDriver::FlowLib.new(ONE_FLOW_URL, one_auth).get_unique_template_id('test_simple_from_hash')

one_flow_template 'gary' do
  name 'gary2'
  template id
  template_options :name => 'test_branch_from_one_id',
                   :description => 'my description is very descriptive',
                   :roles => [
                     {
                       :name => 'gary_ubuntu_2',
                       :delete_role => true
                     },
                     {
                       :name => 'gary_ubuntu',
                       :scheduled_policies => [
                         {
                           :type => "CHANGE",
                           :adjust => 1,
                           :start_time => "0 3 1-10 * *"
                         },
                         {
                           :type => "CARDINALITY",
                           :recurrence => "0 4 1-10 * *",
                           :adjust => 2
                         }
                       ]
                     }
                   ]
end
