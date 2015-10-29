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

require 'chef/provider/one_user'

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
    class OneUser < Chef::Resource::LWRPBase
      resource_name :one_user

      attribute :name, :kind_of => String, :name_attribute => true
      attribute :user_id, :kind_of => Integer
      attribute :password, :kind_of => String
      attribute :groups, :kind_of => Array
      attribute :quotas, :kind_of => Array
      attribute :template_file, :kind_of => String
      attribute :template, :kind_of => Hash
      attribute :append, :kind_of => [TrueClass, FalseClass], :default => true
      attribute :driver

      actions :update, :create, :delete
      default_action :update

      def initialize(*args)
        super
        @driver = run_context.chef_provisioning.current_driver
      end
    end
  end
end
