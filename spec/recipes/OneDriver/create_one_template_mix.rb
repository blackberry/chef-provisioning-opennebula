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

def i?(s)
  !!(s =~ /\A[-+]?[0-9]+\z/)
end

@n = 0
def int_or_str?
  @n += 1
  @n.even? ? :int : :string
end

# supports Hash, Array
def mix_ints_and_strings(data)
  case data
  when Hash
    data.map { |k, v| [k, mix_ints_and_strings(v)] }.to_h
  when Array
    data.map { |x| mix_ints_and_strings(x) }
  when String
    if i?(data)
      int_or_str? == :int ? data.to_i : data
    else
      data
    end
  when Fixnum
    int_or_str? == :string ? data.to_s : data
  else
    data
  end
end

vm_template = mix_ints_and_strings(VM_TEMPLATE)

one_template 'OpenNebula-test-tpl-mix' do
  template vm_template
  mode '666'
  action :create
end
