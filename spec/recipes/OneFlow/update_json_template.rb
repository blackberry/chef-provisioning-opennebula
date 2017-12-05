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

one_flow_template 'RSpec-flow-json-template' do
  template :deployment => 'none',
           :ready_status_gate => false,
           :roles => [
             {
               :name => 'RSpecTest',
               :cooldown => 2,
               :min_vms => 1,
               :max_vms => 5,
               :scheduled_policies => [
                 {
                   :type => "PERCENTAGE_CHANGE",
                   :cooldown => 2,
                   :recurrence => "0 1 1-10 * *",
                   :adjust => 1,
                   :min_adjust_step => 5
                 }
               ]
             },
             {
               :name => 'RSpecRetest',
               :vm_template => 'RSpec-test-template',
               :cooldown => 2,
               :min_vms => 1,
               :max_vms => 5,
               :elasticity_policies => [
                 {
                   :type => "CHANGE",
                   :cooldown => 2,
                   :period => 2,
                   :adjust => 1,
                   :period_number => 1,
                   :expression => "ATT == 20"
                 },
                 {
                   :type => "CARDINALITY",
                   :cooldown => 2,
                   :period => 2,
                   :adjust => 1,
                   :period_number => 1,
                   :expression => "ATT > 20"
                 }
               ]
             }
           ]
end
