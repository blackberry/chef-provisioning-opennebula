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
    class OneTemplate < Chef::Provider::LWRPBase
      use_inline_resources

      provides :one_template

      attr_reader :template

      def whyrun_supported?
        true
      end

      def load_current_resource
      end

      def action_handler
        @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
      end

      def exists?
        new_driver = driver
        @template = new_driver.one.get_resource('tpl', :name => new_resource.name)
        !@template.nil?
      end

      action :create do
        if exists?
          action_handler.report_progress "template '#{new_resource.name}' already exists - nothing to do"
        else
          fail "Missing attribute 'template_file' or 'template'" if !new_resource.template_file && !new_resource.template
          action_handler.perform_action "create template '#{new_resource.name}'" do
            template_str = File.read(new_resource.template_file) if new_resource.template_file
            template_str = new_driver.one.create_template(new_resource.template) if new_resource.template
            template_str << "\nNAME=\"#{new_resource.name}\""
            @template = new_driver.one.allocate_template(template_str)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :delete do
        if !exists?
          action_handler.report_progress "template '#{new_resource.name}' does not exists - nothing to do"
        else
          action_handler.perform_action "delete template '#{new_resource.name}'" do
            @template.delete
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      protected

      def driver
        if current_driver && current_driver.driver_url != new_driver.driver_url
          fail "Cannot move '#{machine_spec.name}' from #{current_driver.driver_url} to #{new_driver.driver_url}: machine moving is not supported.  Destroy and recreate."
        end
        fail "Driver not specified for one_image #{new_resource.name}" unless new_driver
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
