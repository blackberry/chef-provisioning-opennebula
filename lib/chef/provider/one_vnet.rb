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
    class OneVnet < Chef::Provider::LWRPBase
      use_inline_resources

      provides :one_vnet

      attr_reader :current_vnet

      def action_handler
        @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
      end

      def exists?(filter)
        new_driver = driver
        @current_vnet = new_driver.one.get_resource('vnet', filter)
        Chef::Log.debug("VNET '#{filter}' exists: #{!@current_vnet.nil?}")
        !@current_vnet.nil?
      end

      action :create do
        fail "Missing attribute 'template_file'" unless @new_resource.template_file
        fail "Missing attribute 'cluster_id'" unless @new_resource.cluster_id

        if exists?(:name => @new_resource.name)
          action_handler.report_progress "vnet '#{@new_resource.name}' already exists - nothing to do"
        else
          action_handler.perform_action "created vnet '#{@new_resource.name}' from '#{@new_resource.template_file}'" do
            template_str = ::File.read(@new_resource.template_file) + "\nNAME=\"#{@new_resource.name}\""
            vnet = OpenNebula::Vnet.new(OpenNebula::Vnet.build_xml, @client)
            vnet = vnet.allocate(template_str, @new_resource.cluster_id) unless OpenNebula.is_error?(vnet)
            Chef::Log.debug(template_str)
            fail "failed to create vnet '#{@new_resource.name}': #{vnet.message}" if OpenNebula.is_error?(vnet)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :delete do
        if exists?(:id => @new_resource.vnet_id, :name => @new_resource.name)
          action_handler.perform_action "deleted vnet '#{new_resource.name}' (#{@current_vnet.id})" do
            rc = @current_vnet.delete
            fail "failed to delete vnet '#{@new_resource.name}': #{rc.message}" if OpenNebula.is_error?(rc)
            @new_resource.updated_by_last_action(true)
          end
        else
          action_handler.report_progress "vnet '#{new_resource.name}' does not exists - nothing to do"
        end
      end

      action :reserve do
        fail "Missing attribute 'network'" unless @new_resource.network

        if exists?(:name => @new_resource.name)
          hash = @current_vnet.to_hash
          ar_pool = [hash['VNET']['AR_POOL']].flatten
          Chef::Log.debug(@current_vnet.to_hash)
          same = false
          if @new_resource.ar_id && @new_resource.ar_id > -1
            ar_pool.each do |ar|
              same = true if ar['AR']['AR_ID'] == @new_resource.ar_id.to_s && ar['AR']['SIZE'].to_i == @new_resource.size
            end
          else
            same = ar_pool[0]['AR']['SIZE'].to_i == @new_resource.size
          end
          if same
            action_handler.report_progress "vnet '#{@new_resource.name}' already exists - nothing to do"
          else
            fail "vnet '#{@new_resource.name}' exists with different configuration"
          end
        else
          fail "parent network '#{@new_resource.network}' does not exist" unless exists?(:id => @new_resource.network)
          action_handler.perform_action "reserved vnet '#{@new_resource.name}'" do
            rc = @current_vnet.reserve(@new_resource.name, @new_resource.size.to_s, @new_resource.ar_id.to_s, @new_resource.mac_ip, nil)
            fail "Failed to reserve new vnet in network (#{@new_resource.network}): #{rc.message}" if OpenNebula.is_error?(rc)
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
