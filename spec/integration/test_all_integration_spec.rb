# Copyright 2016, BlackBerry, Inc.
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

describe 'OneDriver' do
  describe 'create_one_template_spec.rb' do
    test_helper(
      'create_one_template_spec.rb',
      'OneDriver/create_one_template_spec.rb',
      "create template 'OpenNebula-test-tpl'"
    )
  end

  describe 'create_one_template_int_spec.rb' do
    test_helper(
      'create_one_template_int_spec.rb',
      'OneDriver/create_one_template_int_spec.rb',
      "create template 'OpenNebula-test-tpl-ints'"
    )
  end

  describe 'instantiate_one_template_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/instantiate_one_template_spec.rb',
        "created vm 'OpenNebula-tpl-1-vm'"
      )
    end
  end

  describe 'create_bootstrap_vm_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/create_bootstrap_vm_spec.rb',
        "created vm 'OpenNebula-bootstrap-vm'"
      )
    end
  end

  describe 'create_one_image_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/create_one_image_spec.rb',
        /allocated image 'OpenNebula-bootstrap-img'.*?wait for image 'OpenNebula-bootstrap-img' to be READY/m
      )
    end
  end
  describe 'create_one_image_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/create_one_image_spec.rb',
        /image 'OpenNebula-bootstrap-img' already exists - nothing to do.*?image 'OpenNebula-bootstrap-img' is already in READY state - nothing to do/m
      )
    end
  end

  describe 'attach_one_image_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/attach_one_image_spec.rb',
        /disk not attached, attaching.*?attached disk OpenNebula-bootstrap-img to OpenNebula-bootstrap-vm/m
      )
    end
  end
  describe 'attach_one_image_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/attach_one_image_spec.rb',
        /disk is already attached.*?attached disk OpenNebula-bootstrap-img to OpenNebula-bootstrap-vm/m
      )
    end
  end

  describe 'snapshot_one_image_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/snapshot_one_image_spec.rb',
        "created snapshot from 'OpenNebula-bootstrap-vm'"
      )
    end
  end

  describe 'converge_bootstrap_vm_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/converge_bootstrap_vm_spec.rb',
        /vm 'OpenNebula-bootstrap-vm' is ready.*?create client OpenNebula-bootstrap-vm at clients.*?run 'chef-client -l info' on OpenNebula-bootstrap-vm/m
      )
    end
  end

  # deploys two test backend VM's
  describe 'snapshot_two_image_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/snapshot_two_image_spec.rb',
        "created snapshot from 'OpenNebula-bootstrap-vm'"
      )
    end
  end

  describe 'create_back_one_vm_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/create_back_one_vm_spec.rb',
        /created vm 'OpenNebula-back-1-vm'.*?create node OpenNebula-back-1-vm.*?vm 'OpenNebula-back-1-vm' is ready.*?update node OpenNebula-back-1-vm/m
      )
    end
  end

  describe 'attach_back_one_vm_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/attach_back_one_vm_spec.rb',
        /disk not attached, attaching.*?attached disk OpenNebula-snap-1-img to OpenNebula-back-1-vm/m
      )
    end
  end
  describe 'attach_back_one_vm_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/attach_back_one_vm_spec.rb',
        /disk is already attached.*?attached disk OpenNebula-snap-1-img to OpenNebula-back-1-vm/m
      )
    end
  end

  describe 'converge_back_one_vm_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/converge_back_one_vm_spec.rb',
        /vm 'OpenNebula-back-1-vm' is ready.*?create client OpenNebula-back-1-vm at clients.*?run 'chef-client -l info' on OpenNebula-back-1-vm/m
      )
    end
  end

  describe 'create_back_two_vm_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/create_back_two_vm_spec.rb',
        /created vm 'OpenNebula-back-2-vm'.*?create node OpenNebula-back-2-vm.*?vm 'OpenNebula-back-2-vm' is ready.*?update node OpenNebula-back-2-vm/m
      )
    end
  end

  describe 'attach_back_two_vm_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/attach_back_two_vm_spec.rb',
        /disk not attached, attaching.*?attached disk OpenNebula-snap-2-img to OpenNebula-back-2-vm/m
      )
    end
  end
  describe 'attach_back_two_vm_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/attach_back_two_vm_spec.rb',
        /disk is already attached.*?attached disk OpenNebula-snap-2-img to OpenNebula-back-2-vm/m
      )
    end
  end

  describe 'converge_back_two_vm_spec.rb' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/converge_back_two_vm_spec.rb',
        /vm 'OpenNebula-back-2-vm' is ready.*?create client OpenNebula-back-2-vm at clients.*?run 'chef-client -l info' on OpenNebula-back-2-vm/m
      )
    end
  end

  #############
  ## CLEANUP ##
  #############

  describe 'delete OpenNebula-test-tpl' do
    test_helper(
      'delete OpenNebula-test-tpl',
      'OneDriver/delete/OpenNebula-test-tpl.rb',
      "delete template 'OpenNebula-test-tpl'"
    )
  end

  describe 'delete OpenNebula-test-tpl-ints' do
    test_helper(
      'delete OpenNebula-test-tpl-ints',
      'OneDriver/delete/OpenNebula-test-tpl-ints.rb',
      "delete template 'OpenNebula-test-tpl-ints'"
    )
  end

  describe 'delete OpenNebula-tpl-1-vm' do
    test_helper(
      'delete OpenNebula-tpl-1-vm',
      'OneDriver/delete/OpenNebula-tpl-1-vm.rb',
      /destroyed machine OpenNebula-tpl-1-vm.*?delete node OpenNebula-tpl-1-vm.*?delete client OpenNebula-tpl-1-vm at clients/m
    )
  end

  describe 'delete OpenNebula-bootstrap-vm' do
    test_helper(
      'delete OpenNebula-bootstrap-vm',
      'OneDriver/delete/OpenNebula-bootstrap-vm.rb',
      /destroyed machine OpenNebula-bootstrap-vm.*?delete node OpenNebula-bootstrap-vm.*?delete client OpenNebula-bootstrap-vm at clients/m
    )
  end

  describe 'delete OpenNebula-bootstrap-img' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/delete/OpenNebula-bootstrap-img.rb',
        "deleted image 'OpenNebula-bootstrap-img'"
      )
    end
  end
  describe 'delete OpenNebula-bootstrap-img' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/delete/OpenNebula-bootstrap-img.rb',
        "image 'OpenNebula-bootstrap-img' does not exist - nothing to do"
      )
    end
  end

  describe 'delete OpenNebula-back-1-vm' do
    test_helper(
      'delete OpenNebula-back-1-vm',
      'OneDriver/delete/OpenNebula-back-1-vm.rb',
      /destroyed machine OpenNebula-back-1-vm.*?delete node OpenNebula-back-1-vm.*?delete client OpenNebula-back-1-vm at clients/m
    )
  end

  describe 'delete OpenNebula-back-2-vm' do
    test_helper(
      'delete OpenNebula-back-2-vm',
      'OneDriver/delete/OpenNebula-back-2-vm.rb',
      /destroyed machine OpenNebula-back-2-vm.*?delete node OpenNebula-back-2-vm.*?delete client OpenNebula-back-2-vm at clients/m
    )
  end

  describe 'delete OpenNebula-snap-1-img' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/delete/OpenNebula-snap-1-img.rb',
        "deleted image 'OpenNebula-snap-1-img'"
      )
    end
  end
  describe 'delete OpenNebula-snap-1-img' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/delete/OpenNebula-snap-1-img.rb',
        "image 'OpenNebula-snap-1-img' does not exist - nothing to do"
      )
    end
  end

  describe 'delete OpenNebula-snap-2-img' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/delete/OpenNebula-snap-2-img.rb',
        "deleted image 'OpenNebula-snap-2-img'"
      )
    end
  end
  describe 'delete OpenNebula-snap-2-img' do
    it do
      is_expected.to converge_test_recipe(
        'OneDriver/delete/OpenNebula-snap-2-img.rb',
        "image 'OpenNebula-snap-2-img' does not exist - nothing to do"
      )
    end
  end
end
