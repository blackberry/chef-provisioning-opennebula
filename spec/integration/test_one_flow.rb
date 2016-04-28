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

require 'spec_helper'
require 'chef/provisioning/opennebula_driver'
require "#{File.dirname(__FILE__)}/../config.rb"

describe 'OneFlow' do
  ########################
  ## CREATE VM TEMPLATE ##
  ########################

  describe 'create_one_template_strings.rb' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'OneDriver/create_one_template_strings.rb',
        :expected => "create template 'OpenNebula-test-tpl-strings'"
      )
    end
  end

  ###########################
  ## CREATE FLOW TEMPLATES ##
  ###########################

  describe ':create' do
    idempotency_helper(
      'Create simple flow template from hash',
      'OneFlowTemplate/create_simple_from_hash.rb',
      "created template 'test_simple_from_hash'"
    )
  end

  describe ':create' do
    idempotency_helper(
      'Update simple flow template from hash',
      'OneFlowTemplate/update_simple_from_hash.rb',
      "updated template 'test_simple_from_hash'"
    )
  end

  describe ':create' do
    idempotency_helper(
      'Chmod simple flow template from hash',
      'OneFlowTemplate/chmod_simple_from_hash.rb',
      "updated template 'test_simple_from_hash'"
    )
  end

  describe ':create' do
    idempotency_helper(
      'Update simple flow template from web',
      'OneFlowTemplate/create_simple_from_web.rb',
      "created template 'test_simple_from_web'"
    )
  end

  describe ':create' do
    before(:context) do
      File.open('/tmp/one_rspec_test.json', 'w') do |f|
        f.write(
          {
            :roles => [
              {
                :name => 'gary_ubuntu',
                :vm_template => Chef::Provisioning::OpenNebulaDriver.get_onelib(
                  :driver_url => DRIVER_URL
                ).get_resource(:template, :name => 'OpenNebula-test-tpl-strings').to_hash['VMTEMPLATE']['ID'].to_i
              }
            ]
          }.to_json
        )
      end
    end
    idempotency_helper(
      'Create simple flow template from file',
      'OneFlowTemplate/create_simple_from_file.rb',
      "created template 'test_simple_from_file'"
    )
    after(:context) do
      File.delete('/tmp/one_rspec_test.json')
    end
  end

  describe ':create' do
    before(:context) do
      File.open('/tmp/one_rspec_test.json', 'w') do |f|
        f.write(
          {
            :name => 'test_simple_from_file',
            :roles => [
              {
                :name => 'gary_ubuntu',
                :delete_role => true
              },
              {
                :name => 'gary_ubuntu_new',
                :vm_template => Chef::Provisioning::OpenNebulaDriver.get_onelib(
                  :driver_url => DRIVER_URL
                ).get_resource(:template, :name => 'OpenNebula-test-tpl-strings').to_hash['VMTEMPLATE']['ID'].to_i
              }
            ]
          }.to_json
        )
      end
    end
    idempotency_helper(
      'Chmod and update simple flow template from file',
      'OneFlowTemplate/chmod_update_simple_from_file.rb',
      "updated template 'test_simple_from_file'"
    )
    after(:context) do
      File.delete('/tmp/one_rspec_test.json')
    end
  end

  describe ':create' do
    idempotency_helper(
      'Create flow template with template_options from hash',
      'OneFlowTemplate/create_tpl_opts_from_hash.rb',
      "created template 'test_tpl_opts_from_hash'"
    )
  end

  describe ':create' do
    before(:context) do
      File.open('/tmp/one_rspec_test.json', 'w') do |f|
        f.write(
          {
            :name => 'gary',
            :deployment => 'straight',
            :roles => [
              {
                :name => 'gary_ubuntu',
                :vm_template => Chef::Provisioning::OpenNebulaDriver.get_onelib(
                  :driver_url => DRIVER_URL
                ).get_resource(:template, :name => 'OpenNebula-test-tpl-strings').to_hash['VMTEMPLATE']['ID'].to_i
              }
            ]
          }.to_json
        )
      end
    end
    idempotency_helper(
      'Create flow template with template_options from file',
      'OneFlowTemplate/create_tpl_opts_from_file.rb',
      "created template 'test_tpl_opts_from_file'"
    )
    after(:context) do
      File.delete('/tmp/one_rspec_test.json')
    end
  end

  describe ':create' do
    idempotency_helper(
      'Create flow template that branch off of \'test_simple_from_hash\' by name',
      'OneFlowTemplate/create_branch_from_one_name.rb',
      "created template 'test_branch_from_one_name'"
    )
  end

  describe ':create' do
    idempotency_helper(
      'Create flow template that branch off of \'test_simple_from_hash\' by id',
      'OneFlowTemplate/create_branch_from_one_id.rb',
      "created template 'test_branch_from_one_id'"
    )
  end

  describe ':create' do
    idempotency_helper(
      'Create simple instance flow template',
      'OneFlowTemplate/create_simple_instance_tpl.rb',
      "created template 'test_simple_instance_tpl'"
    )
  end

  describe ':create' do
    idempotency_helper(
      'Create flow template which will be used to test all role actions',
      'OneFlowTemplate/create_role_action_instance.rb',
      "created template 'test_role_action_instance'"
    )
  end

  ###########################
  ## INSTANTIATE TEMPLATES ##
  ###########################

  describe ':instantiate' do
    idempotency_helper(
      'Create simple instance by name',
      'OneFlowService/instance_simple_by_name.rb',
      "instantiated service 'test_simple_instance'"
    )
  end

  describe ':instantiate' do
    idempotency_helper(
      'Create simple instance by id',
      'OneFlowService/instance_simple_by_id.rb',
      "instantiated service 'test_simple_instance_by_id'"
    )
  end

  describe ':instantiate' do
    idempotency_helper(
      'Create simple instance with template_options',
      'OneFlowService/instance_tpl_opts.rb',
      "instantiated service 'test_instance_template_options'"
    )
  end

  describe ':instantiate' do
    idempotency_helper(
      'Chmod simple instance',
      'OneFlowService/chmod_simple_by_name.rb',
      "updated service 'test_simple_instance'"
    )
  end

  describe ':instantiate' do
    idempotency_helper(
      'Chmod simple instance',
      'OneFlowService/chmod_simple_by_name_2.rb',
      "updated service 'test_simple_instance'"
    )
  end

  describe ':instantiate' do
    idempotency_helper(
      'Chmod simple instance with template_options',
      'OneFlowService/chmod_tpl_opts.rb',
      "updated service 'test_instance_template_options'"
    )
  end

  describe ':instantiate' do
    idempotency_helper(
      'Create instance for testing role actions',
      'OneFlowService/instance_role_action.rb',
      "instantiated service 'test_role_action'"
    )
  end

  describe ':snapshot_create' do
    context 'Snapshot of a role' do
      it do
        is_expected.to converge_test_recipe(
          :recipe => 'OneFlowService/action/snapshot_create.rb',
          :expected => "created a snapshot for role 'snapshot_create' of service 'test_role_action'"
        )
      end
    end
  end

  describe ':scale' do
    idempotency_helper(
      'Scale a role',
      'OneFlowService/action/scale.rb',
      "scaled role 'scale' of service 'test_role_action' to cardinality '2'"
    )
  end

  describe ':shutdown' do
    idempotency_helper(
      'Shutdown a role',
      'OneFlowService/action/shutdown.rb',
      "shutdown role 'shutdown' of service 'test_role_action'"
    )
  end

  describe ':shutdown_hard' do
    idempotency_helper(
      'Shutdown-hard a role',
      'OneFlowService/action/shutdown_hard.rb',
      "performed hard shutdown of role 'shutdown_hard' of service 'test_role_action'"
    )
  end

  describe ':undeploy' do
    idempotency_helper(
      'Undeploy a role',
      'OneFlowService/action/undeploy.rb',
      "undeployed role 'undeploy' of service 'test_role_action'"
    )
  end

  describe ':undeploy_hard' do
    idempotency_helper(
      'Undeploy-hard a role',
      'OneFlowService/action/undeploy_hard.rb',
      "hard undeployed role 'undeploy_hard' of service 'test_role_action'"
    )
  end

  describe ':hold' do
    context 'Hold a role' do
      it do
        is_expected.to converge_test_recipe(
          :recipe => 'OneFlowService/action/hold.rb',
          :expected => "held role 'hold' of service 'test_role_action'"
        )
      end
    end
  end

  describe ':release' do
    context 'Release of a role' do
      it do
        is_expected.to converge_test_recipe(
          :recipe => 'OneFlowService/action/release.rb',
          :expected => "released role 'release' of service 'test_role_action'"
        )
      end
    end
  end

  describe ':suspend' do
    idempotency_helper(
      'Suspend a role',
      'OneFlowService/action/suspend.rb',
      "suspended role 'suspend_resume' of service 'test_role_action'"
    )
  end

  describe ':resume' do
    idempotency_helper(
      'Resume a role',
      'OneFlowService/action/resume.rb',
      "resumed role 'suspend_resume' of service 'test_role_action'"
    )
  end

  describe ':boot' do
    context 'Boot a role' do
      it do
        is_expected.to converge_test_recipe(
          :recipe => 'OneFlowService/action/boot.rb',
          :expected => "booted role 'boot' of service 'test_role_action'"
        )
      end
    end
  end

  describe ':delete' do
    idempotency_helper(
      'Delete a role',
      'OneFlowService/action/delete.rb',
      "deleted role 'delete' of service 'test_role_action'"
    )
  end

  describe ':delete_recreate' do
    context 'Delete recreate a role' do
      it do
        is_expected.to converge_test_recipe(
          :recipe => 'OneFlowService/action/delete_recreate.rb',
          :expected => "deleted and recreated role 'delete_recreate' of service 'test_role_action'"
        )
      end
    end
  end

  describe ':reboot' do
    context 'Reboot recreate a role' do
      it do
        is_expected.to converge_test_recipe(
          :recipe => 'OneFlowService/action/reboot.rb',
          :expected => "rebooted role 'reboot' of service 'test_role_action'"
        )
      end
    end
  end

  describe ':reboot_hard' do
    context 'Reboot hard a role' do
      it do
        is_expected.to converge_test_recipe(
          :recipe => 'OneFlowService/action/reboot_hard.rb',
          :expected => "hard rebooted role 'reboot_hard' of service 'test_role_action'"
        )
      end
    end
  end

  describe ':poweroff' do
    idempotency_helper(
      'Poweroff a role',
      'OneFlowService/action/poweroff.rb',
      "powered-off role 'poweroff' of service 'test_role_action'"
    )
  end

  describe ':poweroff_hard' do
    idempotency_helper(
      'Poweroff hard a role',
      'OneFlowService/action/poweroff_hard.rb',
      "hard powered-off role 'poweroff_hard' of service 'test_role_action'"
    )
  end

  describe ':shutdown' do
    idempotency_helper(
      'Shutdown the service',
      'OneFlowService/action/shutdown_service.rb',
      "shutdown service 'test_role_action'"
    )
  end

  #####################
  ## DELETE SERVICES ##
  #####################

  describe ':delete' do
    idempotency_helper(
      'Delete service test_simple_instance',
      'OneFlowService/delete/test_simple_instance.rb',
      "deleted service 'test_simple_instance'"
    )
  end

  describe ':delete' do
    idempotency_helper(
      'Delete service test_simple_instance_by_id',
      'OneFlowService/delete/test_simple_instance_by_id.rb',
      "deleted service 'test_simple_instance_by_id'"
    )
  end

  describe ':delete' do
    idempotency_helper(
      'Delete service test_instance_template_options',
      'OneFlowService/delete/test_instance_template_options.rb',
      "deleted service 'test_instance_template_options'"
    )
  end

  describe ':delete' do
    idempotency_helper(
      'Delete service test_role_action',
      'OneFlowService/delete/test_role_action.rb',
      "deleted service 'test_role_action'"
    )
  end

  ###########################
  ## DELETE FLOW TEMPLATES ##
  ###########################

  describe ':delete' do
    idempotency_helper(
      'Delete simple flow template from hash',
      'OneFlowTemplate/delete/simple_from_hash.rb',
      "deleted template 'test_simple_from_hash'"
    )
  end

  describe ':delete' do
    idempotency_helper(
      'Delete simple flow template from web',
      'OneFlowTemplate/delete/simple_from_web.rb',
      "deleted template 'test_simple_from_web'"
    )
  end

  describe ':delete' do
    idempotency_helper(
      'Delete simple flow template from file',
      'OneFlowTemplate/delete/simple_from_file.rb',
      "deleted template 'test_simple_from_file'"
    )
  end

  describe ':delete' do
    idempotency_helper(
      'Delete flow template with template_options from hash',
      'OneFlowTemplate/delete/tpl_opts_from_hash.rb',
      "deleted template 'test_tpl_opts_from_hash'"
    )
  end

  describe ':delete' do
    idempotency_helper(
      'Delete flow template with template_options from file',
      'OneFlowTemplate/delete/tpl_opts_from_file.rb',
      "deleted template 'test_tpl_opts_from_file'"
    )
  end

  describe ':delete' do
    idempotency_helper(
      'Delete flow template that branch off of \'test_simple_from_hash\' by name',
      'OneFlowTemplate/delete/branch_from_one_name.rb',
      "deleted template 'test_branch_from_one_name'"
    )
  end

  describe ':delete' do
    idempotency_helper(
      'Delete flow template that branch off of \'test_simple_from_hash\' by id',
      'OneFlowTemplate/delete/branch_from_one_id.rb',
      "deleted template 'test_branch_from_one_id'"
    )
  end

  describe ':delete' do
    idempotency_helper(
      'Delete simple instance flow template',
      'OneFlowTemplate/delete/simple_instance_tpl.rb',
      "deleted template 'test_simple_instance_tpl'"
    )
  end

  describe ':delete' do
    idempotency_helper(
      'Delete role action flow template',
      'OneFlowTemplate/delete/role_action_instance.rb',
      "deleted template 'test_role_action_instance'"
    )
  end

  ########################
  ## DELETE VM TEMPLATE ##
  ########################

  describe 'delete OpenNebula-test-tpl-strings' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'OneDriver/delete/OpenNebula-test-tpl-strings.rb',
        :expected => "delete template 'OpenNebula-test-tpl-strings'"
      )
    end
  end
end
