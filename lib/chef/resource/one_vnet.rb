# Copyright 2015, BlackBerry, Inc.
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

require 'chef/provider/one_vnet'

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
    class OneVnet < Chef::Resource::LWRPBase
      resource_name :one_vnet

      attribute :name, :kind_of => String, :name_attribute => true
      attribute :vnet_id, :kind_of => Integer
      attribute :network, :kind_of => Integer
      attribute :size, :kind_of => Integer, :default => 1
      attribute :mac_ip, :kind_of => String
      attribute :ar_id, :kind_of => Integer
      attribute :template_file, :kind_of => String
      attribute :cluster_id, :kind_of => Integer
      attribute :mode, :regex => [/^\d\d\d$/]

      attribute :driver

      actions :reserve, :create, :delete
      default_action :reserve

      def initialize(*args)
        super
        @driver = run_context.chef_provisioning.current_driver
      end
    end
  end
end
