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

describe 'OneDriver/create_one_template.rb' do
  it { is_expected.to converge_with_result(/create template 'RSpec-test-template'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneDriver/update_one_template.rb' do
  it { is_expected.to converge_with_result(/update template content on 'RSpec-test-template'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneDriver/create_one_vnet.rb' do
  it { is_expected.to converge_with_result(/reserved vnet 'RSpec-test-vnet'/) }
  it { is_expected.to converge_with_result(/vnet 'RSpec-test-vnet' already exists/) }
end

describe 'OneDriver/allocate_one_vm.rb' do
  it { is_expected.to converge_with_result(/created vm 'RSpec-test-vm'/,
                                           /create node RSpec-test-vm/) }
end

describe 'OneDriver/ready_one_vm.rb' do
  it { is_expected.to converge_with_result(/vm 'RSpec-test-vm' is ready/,
                                           /update node RSpec-test-vm/) }
end

describe 'OneDriver/converge_one_vm.rb' do
  it { is_expected.to converge_with_result(/vm 'RSpec-test-vm' is ready/,
                                           /generate private key/,
                                           /write file \/etc\/chef\/client.pem on RSpec-test-vm/,
                                           /create client RSpec-test-vm at clients/,
                                           /write file \/etc\/chef\/client.rb on RSpec-test-vm/,
                                           /run 'chef-client -c \/etc\/chef\/client.rb -l info' on RSpec-test-vm/) }
end

describe 'OneDriver/create_one_image.rb' do
  it { is_expected.to converge_with_result(/allocated image 'RSpec-test-img'/,
                                           /wait for image 'RSpec-test-img' to be READY/) }
end

describe 'OneDriver/attach_one_image.rb' do
  it { is_expected.to converge_with_result(/disk not attached, attaching/,
                                           /attached disk RSpec-test-img to RSpec-test-vm/) }
end

describe 'OneDriver/snapshot_one_image.rb' do
  it { is_expected.to converge_with_result(/created snapshot from 'RSpec-test-vm'/) }
  it { is_expected.not_to converge_with_result(/snapshot 'RSpec-test-snap-img' already exists/) }
end

describe 'OneDriver/delete_one_snap-img.rb' do
  it { is_expected.to converge_with_result(/deleted image 'RSpec-test-snap-img'/) }
end

describe 'OneDriver/delete_one_vm.rb' do
  it { is_expected.to converge_with_result(/destroyed machine RSpec-test-vm/,
                                           /delete node RSpec-test-vm/,
                                           /delete client RSpec-test-vm/) }
end

describe 'OneDriver/delete_one_template.rb' do
  it { is_expected.to converge_with_result(/delete template 'RSpec-test-template'/) }
end

describe 'OneDriver/delete_one_img.rb' do
  it { is_expected.to converge_with_result(/deleted image 'RSpec-test-img'/) }
end

describe 'OneDriver/delete_one_vnet.rb' do
  it { is_expected.to converge_with_result(/deleted vnet 'RSpec-test-vnet'/) }
end
