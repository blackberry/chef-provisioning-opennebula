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
require "#{File.dirname(__FILE__)}/../config.rb"

describe 'OneDriver' do
  describe 'create_one_template_strings.rb' do
    idempotency_helper(
      'create_one_template_strings.rb',
      'OneDriver/create_one_template_strings.rb',
      "create template 'OpenNebula-test-tpl-strings'"
    )
  end

  describe 'create_one_template_ints.rb' do
    idempotency_helper(
      'create_one_template_ints.rb',
      'OneDriver/create_one_template_ints.rb',
      "create template 'OpenNebula-test-tpl-ints'"
    )
  end

  describe 'create_one_template_mix.rb' do
    idempotency_helper(
      'create_one_template_mix.rb',
      'OneDriver/create_one_template_mix.rb',
      "create template 'OpenNebula-test-tpl-mix'"
    )
  end

  describe 'create_one_vnet.rb' do
    idempotency_helper(
      'create_one_vnet.rb',
      'OneDriver/create_one_vnet.rb',
      "reserved vnet 'OpenNebula-test-vnet'"
    )
  end

  describe 'instantiate_one_template.rb' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'OneDriver/instantiate_one_template.rb',
        :expected => "created vm 'OpenNebula-test-vm'"
      )
    end
  end

  describe 'allocate_change_profile.rb' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'OneDriver/allocate_change_profile.rb',
        :expected => "update normal.chef_provisioning.driver_url from \"#{DRIVER_URL}\" to \"#{DRIVER_URL_2}\""
      )
    end
  end unless DRIVER_URL_2.nil?


  describe 'instantiate_one_template_vnet.rb' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'OneDriver/instantiate_one_template_vnet.rb',
        :expected => "created vm 'OpenNebula-test-vm-vnet'"
      )
    end
  end

  describe 'create_one_image.rb' do
    idempotency_helper(
      'create_one_image.rb',
      'OneDriver/create_one_image.rb',
      /allocated image 'OpenNebula-test-img'.*?wait for image 'OpenNebula-test-img' to be READY/m
    )
  end

  describe 'attach_one_image.rb' do
    idempotency_helper(
      'attach_one_image.rb',
      'OneDriver/attach_one_image.rb',
      /disk not attached, attaching.*?attached disk OpenNebula-test-img to OpenNebula-test-vm/m
    )
  end

  describe 'snapshot_one_image.rb' do
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'OneDriver/snapshot_one_image.rb',
        :expected => "created snapshot from 'OpenNebula-test-vm'"
      )
    end
    it do
      is_expected.to converge_test_recipe(
        :recipe => 'OneDriver/snapshot_one_image.rb',
        :expected => "snapshot 'OpenNebula-test-snap-img' already exists"
      )
    end
  end

  #############
  ## DELETES ##
  #############

  describe 'delete OpenNebula-test-tpl-strings' do
    idempotency_helper(
      'delete OpenNebula-test-tpl-strings',
      'OneDriver/delete/OpenNebula-test-tpl-strings.rb',
      "delete template 'OpenNebula-test-tpl-strings'"
    )
  end

  describe 'delete OpenNebula-test-tpl-ints' do
    idempotency_helper(
      'delete OpenNebula-test-tpl-ints',
      'OneDriver/delete/OpenNebula-test-tpl-ints.rb',
      "delete template 'OpenNebula-test-tpl-ints'"
    )
  end

  describe 'delete OpenNebula-test-tpl-mix' do
    idempotency_helper(
      'delete OpenNebula-test-tpl-mix',
      'OneDriver/delete/OpenNebula-test-tpl-mix.rb',
      "delete template 'OpenNebula-test-tpl-mix'"
    )
  end

  describe 'delete OpenNebula-test-vm' do
    idempotency_helper(
      'delete OpenNebula-test-vm',
      'OneDriver/delete/OpenNebula-test-vm.rb',
      /destroyed machine OpenNebula-test-vm.*?delete node OpenNebula-test-vm.*?delete client OpenNebula-test-vm at clients/m
    )
  end

  describe 'delete OpenNebula-test-vm-vnet' do
    idempotency_helper(
      'delete OpenNebula-test-vm-vnet',
      'OneDriver/delete/OpenNebula-test-vm-vnet.rb',
      /destroyed machine OpenNebula-test-vm-vnet.*?delete node OpenNebula-test-vm-vnet.*?delete client OpenNebula-test-vm-vnet at clients/m
    )
  end

  describe 'delete OpenNebula-test-vnet' do
    idempotency_helper(
      'delete OpenNebula-test-vnet',
      'OneDriver/delete/OpenNebula-test-vnet.rb',
      "deleted vnet 'OpenNebula-test-vnet'"
    )
  end

  describe 'delete OpenNebula-test-img' do
    idempotency_helper(
      'delete OpenNebula-test-img',
      'OneDriver/delete/OpenNebula-test-img.rb',
      "deleted image 'OpenNebula-test-img'"
    )
  end

  describe 'delete OpenNebula-test-snap-img' do
    idempotency_helper(
      'delete OpenNebula-test-snap-img',
      'OneDriver/delete/OpenNebula-test-snap-img.rb',
      "deleted image 'OpenNebula-test-snap-img'"
    )
  end
end
