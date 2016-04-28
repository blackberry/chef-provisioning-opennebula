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

require 'chef/provisioning/opennebula_driver/flow_lib'
require 'set'

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
    class OneFlowService < Chef::Provider::LWRPBase
      use_inline_resources

      provides :one_flow_service

      def initialize(*args)
        super
        if !@new_resource.flow_url.nil?
          flow_url = @new_resource.flow_url
        elsif !run_context.chef_provisioning.flow_url.nil?
          flow_url = run_context.chef_provisioning.flow_url
        elsif !ENV['ONE_FLOW_URL'].nil?
          flow_url = ENV['ONE_FLOW_URL']
        else
          fail 'OneFlow API URL must be specified.'
        end
        @flow_lib = Chef::Provisioning::OpenNebulaDriver::FlowLib.new(flow_url, driver.one.client.one_auth)
      end

      def whyrun_supported?
        true
      end

      def load_current_resource
        @current_resource = Chef::Resource::OneFlowService.new(@new_resource.name, run_context)
        service_id = @flow_lib.get_unique_service_id(@new_resource.name, true)

        @current_resource.exists = !service_id.nil?
        return unless @current_resource.exists

        if @new_resource.template.nil?
          @current_resource.template_equal = true
        else
          one_tpl_id = @new_resource.template.is_a?(Fixnum) ? @new_resource.template : @flow_lib.get_unique_template_id(@new_resource.template)
          new_service_template = @flow_lib.get_template(one_tpl_id)
          new_service_template = @flow_lib.normalize_template(@new_resource.name, driver, @flow_lib.merge_template(new_service_template, @new_resource.template_options, true))
          new_service_template.delete(:name)
          new_service_template[:roles].each { |role| [:cardinality, :vm_template_contents].each { |key| role.delete(key) } }
          current_service_template = @flow_lib.get_reduced_service_template(service_id)
          @current_resource.template_equal = @flow_lib.hash_eq?(new_service_template, current_service_template)
        end

        @current_resource.mode(@flow_lib.get_service_permissions(service_id))
        @current_resource.mode_equal = @new_resource.mode == @current_resource.mode

        @current_resource.in_running_state = @flow_lib.get_service_state(service_id) == @flow_lib.class::SERVICE_RUNNING

        @current_resource.equal = @current_resource.template_equal && @current_resource.mode_equal && @current_resource.in_running_state
      end

      action :instantiate do
        if @current_resource.exists
          # recover and/or chmod
          unless @current_resource.equal
            service_id = @flow_lib.get_unique_service_id(@new_resource.name)
            converge_by "updated service '#{@new_resource.name}'" do
              unless @current_resource.in_running_state
                @flow_lib.recover_service(service_id, @new_resource.name)
              end
              unless @current_resource.mode_equal
                @flow_lib.chmod_service(service_id, @new_resource.mode)
              end
              @new_resource.updated_by_last_action(true)
            end
          end
        else
          # create and chmod
          fail 'You must specify a Flow template to instantiate' if @new_resource.template.nil?
          one_tpl_id = @new_resource.template.is_a?(Fixnum) ? @new_resource.template : @flow_lib.get_unique_template_id(@new_resource.template)
          new_service_template = @flow_lib.normalize_template(@new_resource.name, driver, @flow_lib.get_template(one_tpl_id))
          new_service_template = @flow_lib.normalize_template(@new_resource.name, driver, @flow_lib.merge_template(new_service_template, @new_resource.template_options, true))
          new_service_template[:name] = @new_resource.name
          converge_by "instantiated service '#{@new_resource.name}'" do
            one_tpl_id = @new_resource.template.is_a?(Fixnum) ? @new_resource.template : @flow_lib.get_unique_template_id(@new_resource.template)
            @flow_lib.instantiate_template(one_tpl_id, new_service_template, @new_resource.name)
            service_id = @flow_lib.get_unique_service_id(@new_resource.name)
            @flow_lib.chmod_service(service_id, @new_resource.mode)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :recover do
        service_id = @flow_lib.get_unique_service_id(@new_resource.name)
        dont_recover = Set[
          @flow_lib.class::SERVICE_RUNNING,
          @flow_lib.class::SERVICE_DEPLOYING,
          @flow_lib.class::SERVICE_PENDING,
          @flow_lib.class::SERVICE_SCALING
        ].include?(@flow_lib.get_service_state(service_id))
        unless dont_recover
          converge_by "recovered service '#{@new_resource.name}'" do
            @flow_lib.recover_service(service_id, @new_resource.name)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :delete do
        if @new_resource.role.nil?
          if @current_resource.exists
            service_id = @flow_lib.get_unique_service_id(@new_resource.name, true)
            converge_by "deleted service '#{@new_resource.name}'" do
              @flow_lib.delete_service(service_id)
              @new_resource.updated_by_last_action(true)
            end
          end
        else
          sid = @flow_lib.get_unique_service_id(@new_resource.name)
          unless @flow_lib.get_role_state(sid, @new_resource.role) == @flow_lib.class::ROLE_NO_VMS
            converge_by "deleted role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
              @flow_lib.role_action(sid, @new_resource.role, 'delete', @new_resource.period.to_s, @new_resource.number.to_s, @flow_lib.class::ROLE_NO_VMS)
              @new_resource.updated_by_last_action(true)
            end
          end
        end
      end

      action :shutdown do
        if @new_resource.role.nil?
          sid = @flow_lib.get_unique_service_id(@new_resource.name)
          dont_shutdown = Set[
            @flow_lib.class::SERVICE_DONE,
            @flow_lib.class::SERVICE_UNDEPLOYING,
            @flow_lib.class::SERVICE_FAILED_DEPLOYING
          ].include?(@flow_lib.get_service_state(sid))
          unless dont_shutdown
            converge_by "shutdown service '#{@new_resource.name}'" do
              @flow_lib.shutdown_service(@new_resource.name, sid)
              @new_resource.updated_by_last_action(true)
            end
          end
        else
          sid = @flow_lib.get_unique_service_id(@new_resource.name)
          unless @flow_lib.get_role_state(sid, @new_resource.role) == @flow_lib.class::ROLE_NO_VMS
            converge_by "shutdown role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
              @flow_lib.role_action(sid, @new_resource.role, 'shutdown', @new_resource.period.to_s, @new_resource.number.to_s, @flow_lib.class::ROLE_NO_VMS)
              @new_resource.updated_by_last_action(true)
            end
          end
        end
      end

      action :scale do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        fail 'You must specify the attribute cardinality, and cardinality >= 0' if @new_resource.cardinality < 0

        service_id = @flow_lib.get_unique_service_id(@new_resource.name)
        unless @flow_lib.get_role_cardinality(service_id, @new_resource.role) == @new_resource.cardinality
          converge_by "scaled role '#{@new_resource.role}' of service '#{@new_resource.name}' to cardinality '#{@new_resource.cardinality}'" do
            @flow_lib.role_scale(service_id, @new_resource.name, @new_resource.role, @new_resource.cardinality, @new_resource.force_scale)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :shutdown_hard do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        unless @flow_lib.get_role_state(sid, @new_resource.role) == @flow_lib.class::ROLE_NO_VMS
          converge_by "performed hard shutdown of role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
            @flow_lib.role_action(sid, @new_resource.role, 'shutdown-hard', @new_resource.period.to_s, @new_resource.number.to_s, @flow_lib.class::ROLE_NO_VMS)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :undeploy do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        unless @flow_lib.get_role_state(sid, @new_resource.role) == @flow_lib.class::ROLE_UNDEPLOYED
          converge_by "undeployed role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
            @flow_lib.role_action(sid, @new_resource.role, 'undeploy', @new_resource.period.to_s, @new_resource.number.to_s, @flow_lib.class::ROLE_UNDEPLOYED)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :undeploy_hard do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        unless @flow_lib.get_role_state(sid, @new_resource.role) == @flow_lib.class::ROLE_UNDEPLOYED
          converge_by "hard undeployed role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
            @flow_lib.role_action(sid, @new_resource.role, 'undeploy-hard', @new_resource.period.to_s, @new_resource.number.to_s, @flow_lib.class::ROLE_UNDEPLOYED)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :hold do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        @new_resource.override_failsafe ? @flow_lib.override_failsafe_warn : fail('UNTESTED / PARTIALLY IMPLEMENTED')
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        converge_by "held role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
          @flow_lib.role_action(sid, @new_resource.role, 'hold', @new_resource.period.to_s, @new_resource.number.to_s)
          @new_resource.updated_by_last_action(true)
        end
      end

      action :release do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        @new_resource.override_failsafe ? @flow_lib.override_failsafe_warn : fail('UNTESTED / PARTIALLY IMPLEMENTED')
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        converge_by "released role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
          @flow_lib.role_action(sid, @new_resource.role, 'release', @new_resource.period.to_s, @new_resource.number.to_s)
          @new_resource.updated_by_last_action(true)
        end
      end

      action :stop do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        unless @flow_lib.get_role_state(sid, @new_resource.role) == @flow_lib.class::ROLE_STOPPED
          converge_by "stopped role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
            @flow_lib.role_action(sid, @new_resource.role, 'stop', @new_resource.period.to_s, @new_resource.number.to_s, @flow_lib.class::ROLE_STOPPED)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :suspend do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        unless @flow_lib.get_role_state(sid, @new_resource.role) == @flow_lib.class::ROLE_SUSPENDED
          converge_by "suspended role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
            @flow_lib.role_action(sid, @new_resource.role, 'suspend', @new_resource.period.to_s, @new_resource.number.to_s, @flow_lib.class::ROLE_SUSPENDED)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :resume do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        unless @flow_lib.get_role_state(sid, @new_resource.role) == @flow_lib.class::ROLE_RUNNING
          converge_by "resumed role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
            @flow_lib.role_action(sid, @new_resource.role, 'resume', @new_resource.period.to_s, @new_resource.number.to_s, @flow_lib.class::ROLE_RUNNING)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :boot do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        @new_resource.override_failsafe ? @flow_lib.override_failsafe_warn : fail('UNTESTED / PARTIALLY IMPLEMENTED')
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        converge_by "booted role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
          @flow_lib.role_action(sid, @new_resource.role, 'boot', @new_resource.period.to_s, @new_resource.number.to_s)
          @new_resource.updated_by_last_action(true)
        end
      end

      action :delete_recreate do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        converge_by "deleted and recreated role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
          @flow_lib.role_action(sid, @new_resource.role, 'delete-recreate', @new_resource.period.to_s, @new_resource.number.to_s, @flow_lib.class::ROLE_RUNNING)
          @new_resource.updated_by_last_action(true)
        end
      end

      action :reboot do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        converge_by "rebooted role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
          @flow_lib.role_action(sid, @new_resource.role, 'reboot', @new_resource.period.to_s, @new_resource.number.to_s, @flow_lib.class::ROLE_RUNNING)
          @new_resource.updated_by_last_action(true)
        end
      end

      action :reboot_hard do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        converge_by "hard rebooted role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
          @flow_lib.role_action(sid, @new_resource.role, 'reboot-hard', @new_resource.period.to_s, @new_resource.number.to_s, @flow_lib.class::ROLE_RUNNING)
          @new_resource.updated_by_last_action(true)
        end
      end

      action :poweroff do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        unless @flow_lib.get_role_state(sid, @new_resource.role) == @flow_lib.class::ROLE_POWEROFF
          converge_by "powered-off role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
            @flow_lib.role_action(sid, @new_resource.role, 'poweroff', @new_resource.period.to_s, @new_resource.number.to_s, @flow_lib.class::ROLE_POWEROFF)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :poweroff_hard do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        unless @flow_lib.get_role_state(sid, @new_resource.role) == @flow_lib.class::ROLE_POWEROFF
          converge_by "hard powered-off role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
            @flow_lib.role_action(sid, @new_resource.role, 'poweroff-hard', @new_resource.period.to_s, @new_resource.number.to_s, @flow_lib.class::ROLE_POWEROFF)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :snapshot_create do
        fail 'You specified an action that is role specific, but did not provide a role.' if @new_resource.role.nil?
        sid = @flow_lib.get_unique_service_id(@new_resource.name)
        converge_by "created a snapshot for role '#{@new_resource.role}' of service '#{@new_resource.name}'" do
          @flow_lib.role_action(sid, @new_resource.role, 'snapshot-create', @new_resource.period.to_s, @new_resource.number.to_s)
          @new_resource.updated_by_last_action(true)
        end
      end

      protected

      def driver
        @new_resource.driver.nil? ? run_context.chef_provisioning.current_driver : run_context.chef_provisioning.driver_for(@new_resource.driver)
      end
    end
  end
end
