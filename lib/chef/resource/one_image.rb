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

require 'chef/provider/one_image'

#
# Implementation of Resource class.
#
class Chef
  #
  # Implementation of Resource class.
  #
  class Resource
    #
    # Implementation of Resource class.
    #
    class OneImage < Chef::Resource::LWRPBase
      resource_name :one_image

      actions :allocate, :create, :destroy, :attach, :snapshot, :upload, :download
      default_action :create

      attribute :name, :kind_of => String, :name_attribute => true
      attribute :size, :kind_of => Integer
      attribute :datastore_id, :kind_of => Integer
      attribute :driver_options, :kind_of => Hash
      attribute :type, :kind_of => String, :equal_to => %w(OS CDROM DATABLOCK KERNEL RAMDISK CONTEXT)
      attribute :description, :kind_of => String
      attribute :fs_type, :kind_of => String
      attribute :img_driver, :kind_of => String, :default => 'qcow2'
      attribute :prefix, :kind_of => String, :equal_to => %w(vd xvd sd hd)
      attribute :persistent, :kind_of => [TrueClass, FalseClass]
      attribute :public, :kind_of => [TrueClass, FalseClass]
      attribute :mode, :regex => [/^[0-7]{3}$/]
      attribute :disk_type, :kind_of => String
      attribute :source, :kind_of => String
      attribute :target, :kind_of => String
      attribute :machine_id, :kind_of => [String, Integer]
      attribute :disk_id, :kind_of => [String, Integer]
      attribute :image_file, :kind_of => String
      attribute :cache, :kind_of => String
      attribute :download_url, :kind_of => String
      attribute :image_id, :kind_of => Integer
      attribute :http_port, :kind_of => Integer, :default => 8066
      attribute :driver

      def initialize(*args)
        super
        @chef_environment = run_context.cheffish.current_environment
        @chef_server = run_context.cheffish.current_chef_server
        @driver = run_context.chef_provisioning.current_driver
      end
    end
  end
end
