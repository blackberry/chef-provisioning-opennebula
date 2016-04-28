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

one_flow_template 'test_simple_from_hash' do
  template :deployment => 'none',
           :roles => [
             {
               :name => 'gary_ubuntu',
               :min_vms => 1,
               :max_vms => 5,
               :scheduled_policies => [
                 {
                   :type => "PERCENTAGE_CHANGE",
                   :recurrence => "0 1 1-10 * *",
                   :adjust => 3,
                   :min_adjust_step => 14
                 }
               ]
             },
             {
               :name => 'gary_ubuntu_2',
               :vm_template => 'OpenNebula-test-tpl-strings',
               :cooldown => 123,
               :min_vms => 1,
               :max_vms => 5,
               :elasticity_policies => [
                 {
                   :type => "CHANGE",
                   :cooldown => 17,
                   :period => 15,
                   :adjust => 2,
                   :period_number => 2,
                   :expression => "ATT == 20"
                 },
                 {
                   :type => "CARDINALITY",
                   :cooldown => 14,
                   :period => 13,
                   :adjust => 3,
                   :period_number => 1,
                   :expression => "ATT > 20"
                 }
               ]
             }
           ]
end
