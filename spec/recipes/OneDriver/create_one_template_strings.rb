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

# supports Hash, Array
def ints_to_strings(data)
  case data
  when Hash
    data.map { |k, v| [k, ints_to_strings(v)] }.to_h
  when Array
    data.map { |x| ints_to_strings(x) }
  when Fixnum
    data.to_s
  else
    data
  end
end

vm_template = ints_to_strings(VM_TEMPLATE)

one_template 'OpenNebula-test-tpl-strings' do
  template vm_template
  action :create
end
