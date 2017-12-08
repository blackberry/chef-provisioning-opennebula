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

# create/update OneFlow templates

describe 'OneDriver/create_one_template.rb' do
  it { is_expected.to converge_with_result(/create template 'RSpec-test-template'/) }
end

describe 'OneFlow/create_json_template.rb' do
  it { is_expected.to converge_with_result(/created template 'RSpec-flow-json-template'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/update_json_template.rb' do
  it { is_expected.to converge_with_result(/updated template 'RSpec-flow-json-template'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/chmod_json_template.rb' do
  it { is_expected.to converge_with_result(/updated template 'RSpec-flow-json-template'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/create_http_template.rb' do
  it { is_expected.to converge_with_result(/created template 'RSpec-flow-http-template'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/create_file_template.rb' do
  before(:context) do
    File.open('/tmp/RSpec-flow-file-template.json', 'w') do |f|
      f.write(
        { :roles => [
            {
              :name => 'RSpecTest',
              :cooldown => 2,
              :vm_template => Chef::Provisioning::OpenNebulaDriver.get_onelib(:driver_url => DRIVER_URL)
                .get_resource(:template, :name => 'RSpec-test-template').to_hash['VMTEMPLATE']['ID'].to_i
            }
          ]
        }.to_json
      )
    end
  end
  it { is_expected.to converge_with_result(/created template 'RSpec-flow-file-template'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
  after(:context) do
    File.delete('/tmp/RSpec-flow-file-template.json')
  end
end

describe 'OneFlow/chmod_file_template.rb' do
  it { is_expected.to converge_with_result(/updated template 'RSpec-flow-file-template'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/create_json_template_with_opts.rb' do
  it { is_expected.to converge_with_result(/created template 'RSpec-flow-json-template-with-opts'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/create_file_template_with_opts.rb' do
  before(:context) do
    File.open('/tmp/RSpec-flow-file-template-with-opts.json', 'w') do |f|
      f.write(
          {
            :deployment => 'none',
            :ready_status_gate => false,
            :roles => [
              {
                :name => 'RSpecTest',
                :cooldown => 2,
                :vm_template => Chef::Provisioning::OpenNebulaDriver.get_onelib(:driver_url => DRIVER_URL)
                  .get_resource(:template, :name => 'RSpec-test-template').to_hash['VMTEMPLATE']['ID'].to_i
              }
            ]
          }.to_json
      )
    end
  end
  it { is_expected.to converge_with_result(/created template 'RSpec-flow-file-template-with-opts'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
  after(:context) do
    File.delete('/tmp/RSpec-flow-file-template-with-opts.json')
  end
end

describe 'OneFlow/branch_json_template_by_id.rb' do
  it { is_expected.to converge_with_result(/created template 'RSpec-branch-json-template-by-id'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/branch_json_template_by_name.rb' do
  it { is_expected.to converge_with_result(/created template 'RSpec-branch-json-template-by-name'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/create_role_action_template.rb' do
  it { is_expected.to converge_with_result(/created template 'RSpec-role-action-template'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

# instantiate OneFlow services

describe 'OneFlow/create_json_service_with_opts.rb' do
  it { is_expected.to converge_with_result(/instantiated service 'RSpec-json-service-with-opts'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/create_json_service_by_id.rb' do
  it { is_expected.to converge_with_result(/instantiated service 'RSpec-json-service-by-id'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/create_json_service_by_name.rb' do
  it { is_expected.to converge_with_result(/instantiated service 'RSpec-json-service-by-name'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/chmod_json_service_by_id.rb' do
  it { is_expected.to converge_with_result(/updated service 'RSpec-json-service-by-id'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/chmod_json_service_by_name.rb' do
  it { is_expected.to converge_with_result(/updated service 'RSpec-json-service-by-name'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/create_role_action_service.rb' do
  it { is_expected.to converge_with_result(/instantiated service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

# action OneFlow services

describe 'OneFlow/service_action_delete_recreate.rb' do
  it { is_expected.to converge_with_result(
        /deleted and recreated role 'RSpec_delete_recreate' of service 'RSpec-role-action-service'/) }
end

describe 'OneFlow/service_action_snapshot_create.rb' do
  it { is_expected.to converge_with_result(
        /created a snapshot for role 'RSpec_snapshot_create' of service 'RSpec-role-action-service'/) }
end

describe 'OneFlow/service_action_scale.rb' do
  it { is_expected.to converge_with_result(
        /scaled role 'RSpec_scale' of service 'RSpec-role-action-service' to cardinality '2'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_shutdown.rb' do
  it { is_expected.to converge_with_result(
        /shutdown role 'RSpec_shutdown' of service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_shutdown_hard.rb' do
  it { is_expected.to converge_with_result(
        /performed hard shutdown of role 'RSpec_shutdown_hard' of service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_poweroff.rb' do
  it { is_expected.to converge_with_result(
        /powered-off role 'RSpec_poweroff' of service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_poweroff_hard.rb' do
  it { is_expected.to converge_with_result(
        /hard powered-off role 'RSpec_poweroff_hard' of service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_stop.rb' do
  it { is_expected.to converge_with_result(
        /stopped role 'RSpec_stop' of service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_suspend.rb' do
  it { is_expected.to converge_with_result(
        /suspended role 'RSpec_suspend' of service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_undeploy.rb' do
  it { is_expected.to converge_with_result(
        /undeployed role 'RSpec_undeploy' of service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_undeploy_hard.rb' do
  it { is_expected.to converge_with_result(
        /hard undeployed role 'RSpec_undeploy_hard' of service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_resume_poweroff.rb' do
  it { is_expected.to converge_with_result(
        /resumed role 'RSpec_poweroff' of service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_resume_poweroff_hard.rb' do
  it { is_expected.to converge_with_result(
        /resumed role 'RSpec_poweroff_hard' of service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_resume_stop.rb' do
  it { is_expected.to converge_with_result(
        /resumed role 'RSpec_stop' of service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_resume_suspend.rb' do
  it { is_expected.to converge_with_result(
        /resumed role 'RSpec_suspend' of service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_resume_undeploy.rb' do
  it { is_expected.to converge_with_result(
        /resumed role 'RSpec_undeploy' of service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_resume_undeploy_hard.rb' do
  it { is_expected.to converge_with_result(
        /resumed role 'RSpec_undeploy_hard' of service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

describe 'OneFlow/service_action_hold.rb' do
  it { is_expected.not_to converge_with_result(
        /UNTESTED \/ PARTIALLY IMPLEMENTED/) }
end

describe 'OneFlow/service_action_release.rb' do
  it { is_expected.not_to converge_with_result(
        /UNTESTED \/ PARTIALLY IMPLEMENTED/) }
end

describe 'OneFlow/service_action_boot.rb' do
  it { is_expected.not_to converge_with_result(
        /UNTESTED \/ PARTIALLY IMPLEMENTED/) }
end

describe 'OneFlow/service_action_reboot.rb' do
  it { is_expected.to converge_with_result(
        /rebooted role 'RSpec_reboot' of service 'RSpec-role-action-service'/) }
end

describe 'OneFlow/service_action_reboot_hard.rb' do
  it { is_expected.to converge_with_result(
        /hard rebooted role 'RSpec_reboot_hard' of service 'RSpec-role-action-service'/) }
end

describe 'OneFlow/service_action_delete.rb' do
  it { is_expected.to converge_with_result(
        /deleted role 'RSpec_delete_recreate' of service 'RSpec-role-action-service'/) }
end

describe 'OneFlow/shutdown_role_action_service.rb' do
  it { is_expected.to converge_with_result(/shutdown service 'RSpec-role-action-service'/) }
  it { is_expected.to converge_with_result(/(up to date)/) }
end

# delete OneFlow services

describe 'OneFlow/delete_json_service_with_opts.rb' do
  it { is_expected.to converge_with_result(/deleted service 'RSpec-json-service-with-opts'/) }
end

describe 'OneFlow/delete_json_service_by_id.rb' do
  it { is_expected.to converge_with_result(/deleted service 'RSpec-json-service-by-id'/) }
end

describe 'OneFlow/delete_json_service_by_name.rb' do
  it { is_expected.to converge_with_result(/deleted service 'RSpec-json-service-by-name'/) }
end

describe 'OneFlow/delete_role_action_service.rb' do
  it { is_expected.to converge_with_result(/deleted service 'RSpec-role-action-service'/) }
end

# delete OneFlow templates

describe 'OneFlow/delete_json_template.rb' do
  it { is_expected.to converge_with_result(/deleted template 'RSpec-flow-json-template'/) }
end

describe 'OneFlow/delete_http_template.rb' do
  it { is_expected.to converge_with_result(/deleted template 'RSpec-flow-http-template'/) }
end

describe 'OneFlow/delete_file_template.rb' do
  it { is_expected.to converge_with_result(/deleted template 'RSpec-flow-file-template'/) }
end

describe 'OneFlow/delete_json_template_with_opts.rb' do
  it { is_expected.to converge_with_result(/deleted template 'RSpec-flow-json-template-with-opts'/) }
end

describe 'OneFlow/delete_file_template_with_opts.rb' do
  it { is_expected.to converge_with_result(/deleted template 'RSpec-flow-file-template-with-opts'/) }
end

describe 'OneFlow/delete_branched_template_by_id.rb' do
  it { is_expected.to converge_with_result(/deleted template 'RSpec-branch-json-template-by-id'/) }
end

describe 'OneFlow/delete_branched_template_by_name.rb' do
  it { is_expected.to converge_with_result(/deleted template 'RSpec-branch-json-template-by-name'/) }
end

describe 'OneFlow/delete_role_action_template.rb' do
  it { is_expected.to converge_with_result(/deleted template 'RSpec-role-action-template'/) }
end

# delete One template

describe 'OneDriver/delete_one_template.rb' do
  it { is_expected.to converge_with_result(/delete template 'RSpec-test-template'/) }
end
