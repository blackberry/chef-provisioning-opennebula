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

#
# Implementation of Provider class.
#
class Chef
  #
  # Implementation of Provider class.
  #
  class Provider
    #
    # Implementation of Provider class.
    #
    class OneUser < Chef::Provider::LWRPBase
      use_inline_resources

      provides :one_user

      attr_reader :current_user

      def action_handler
        @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
      end

      def exists?(filter)
        new_driver = driver
        @current_user = new_driver.one.get_resource(:user, filter)
        Chef::Log.debug("user '#{filter}' exists: #{!@current_user.nil?}")
        !@current_user.nil?
      end

      action :create do
        fail "Missing attribute 'password'" unless @new_resource.password

        if exists?(:name => @new_resource.name)
          action_handler.report_progress "user '#{@new_resource.name}' already exists - (up to date)"
        else
          action_handler.perform_action "create user '#{@new_resource.name}'" do
            user = OpenNebula::User.new(OpenNebula::User.build_xml, @client)
            rc = user.allocate(@new_resource.name, @new_resource.password) unless OpenNebula.is_error?(user)
            Chef::Log.debug(template_str)
            fail "failed to create vnet '#{@new_resource.name}': #{vnet.message}" if OpenNebula.is_error?(rc)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :delete do
        if exists?(:id => @new_resource.user_id, :name => @new_resource.name)
          action_handler.perform_action "deleted user '#{new_resource.name}' (#{@current_user.id})" do
            rc = @current_user.delete
            fail "failed to delete user '#{@new_resource.name}': #{rc.message}" if OpenNebula.is_error?(rc)
            @new_resource.updated_by_last_action(true)
          end
        else
          action_handler.report_progress "user '#{new_resource.name}' does not exists - (up to date)"
        end
      end

      action :update do
        fail "user '#{new_resource.name}' does not exists" unless exists?(:id => @new_resource.user_id, :name => @new_resource.name)
        fail "':template' or ':template_file' attribute missing" unless @new_resource.template || @new_resource.template_file

        tpl = new_driver.one.create_template(@new_resource.template) if @new_resource.template
        tpl = ::File.read(@new_resource.template_file) if @new_resource.template_file

        rc = @current_user.update(tpl, true)
        fail "failed to update user '#{@new_resource.name}': #{rc.message}" if OpenNebula.is_error?(rc)
      end

      protected

      def driver
        if current_driver && current_driver.driver_url != new_driver.driver_url
          fail "Cannot move '#{machine_spec.name}' from #{current_driver.driver_url} to #{new_driver.driver_url}: machine moving is not supported.  Destroy and recreate."
        end
        fail "Driver not specified for one_user #{new_resource.name}" unless new_driver
        new_driver
      end

      def new_driver
        run_context.chef_provisioning.driver_for(new_resource.driver)
      end

      def current_driver
        run_context.chef_provisioning.driver_for(run_context.chef_provisioning.current_driver) if run_context.chef_provisioning.current_driver
      end
    end
  end
end
