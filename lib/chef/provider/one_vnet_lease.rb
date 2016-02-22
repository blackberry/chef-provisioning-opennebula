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
    class OneVnetLease < Chef::Provider::LWRPBase
      use_inline_resources

      provides :one_vnet_lease

      attr_reader :current_vnet

      def action_handler
        @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
      end

      def exists?
        new_driver = driver
        filter = { @new_resource.vnet.is_a?(Integer) ? :id : :name => @new_resource.vnet }
        @current_vnet = new_driver.one.get_resource(:virtualnetwork, filter)
        fail "vnet '#{@new_resource.vnet}' does not exist" if @current_vnet.nil?
        @current_vnet.info!
        hash = @current_vnet.to_hash

        lookup = @new_resource.name.include?(':') ? 'MAC' : 'IP'
        ar_pool = [hash['VNET']['AR_POOL']].flatten

        if @new_resource.ar_id && @new_resource.ar_id > -1
          ar_pool = get_ar_pool(ar_pool, @new_resource.ar_id.to_s)
          fail "ar_id not found '#{@new_resource.ar_id}'" if ar_pool.nil?
        end
        lease_available?(ar_pool, lookup)
      end

      action :hold do
        if exists?
          action_handler.report_progress("#{@new_resource.name} is already on hold and not used")
        else
          action_handler.perform_action "hold '#{@new_resource.name}'" do
            rc = @current_vnet.hold(@new_resource.name, @new_resource.ar_id || -1)
            fail "Failed to put a hold on '#{@new_resource.name}': #{rc.message}" if OpenNebula.is_error?(rc)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :release do
        if exists?
          action_handler.perform_action "released '#{@new_resource.name}'" do
            rc = @current_vnet.release(@new_resource.name, @new_resource.ar_id || -1)
            fail "Failed to release '#{@new_resource.name}': #{rc.message}" if OpenNebula.is_error?(rc)
            @new_resource.updated_by_last_action(true)
          end
        else
          action_handler.report_progress("#{@new_resource.name} is not present - nothing do to")
        end
      end

      protected

      def get_ar_pool(ar_pool, ar_id)
        ar_pool.each { |a| return [a] if a['AR']['AR_ID'] == ar_id }
        nil
      end

      def lease_available?(ar_pool, lookup)
        exists = false
        vm = -2
        ar_pool.each do |a|
          next unless a['AR']['LEASES']['LEASE']
          [a['AR']['LEASES']['LEASE']].flatten.each do |l|
            next unless l[lookup] && l[lookup] == @new_resource.name
            exists = true
            vm = l['VM'].to_i
            break
          end
        end
        (exists && vm == -1)
      end

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
