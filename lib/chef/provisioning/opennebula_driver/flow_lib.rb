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

require 'rest-client'
require 'json'
require 'set'

#
# Implementation.
#
class Chef
  #
  # Module extension.
  #
  module Provisioning
    #
    # Module extension.
    #
    module OpenNebulaDriver
      #
      # ONE error.
      #
      class OpenNebulaException < Exception
      end

      #
      # Implementation.
      #
      class FlowLib
        attr_accessor :flow_url, :username, :password

        # STATE NUMBERS TO SYMBOLS

        # SERVICE:
        SERVICE_PENDING = 0
        SERVICE_DEPLOYING = 1
        SERVICE_RUNNING = 2
        SERVICE_UNDEPLOYING = 3
        SERVICE_DONE = 5
        SERVICE_FAILED_DEPLOYING = 7
        SERVICE_SCALING = 8
        SERVICE_FAILED_SCALING = 9
        SERVICE_COOLDOWN = 10

        # ROLE:
        ROLE_NOT_EXIST = nil
        ROLE_NO_VMS = -1
        ROLE_PENDING = 1
        ROLE_RUNNING = 3
        ROLE_STOPPED = 4
        ROLE_SUSPENDED = 5
        ROLE_POWEROFF = 8
        ROLE_UNDEPLOYED = 9

        def initialize(url, one_auth)
          @flow_url = url
          @username, _, @password = one_auth.rpartition(':')
        end

        ###########
        # HELPERS #
        ###########

        # Performs some basic verifications on a template
        # Also adds in default values
        def normalize_template(name, driver, template, allow_no_roles = false, allow_no_vm_template = false)
          template = {
            :deployment => 'straight',
            :name => name,
            :ready_status_gate => false,
            :description => '',
            :roles => [],
            :custom_attrs => {}
          }.merge(template)

          fail "You must specify at least 1 role for template '#{name}'" if template[:roles].empty? && !allow_no_roles
          id_cache = {}
          template[:roles].map! do |role|
            fail "Some roles in template '#{name}' are missing a name." if role[:name].nil?
            fail "Role '#{role[:name]}' in template '#{name}' is missing a vm_template." if role[:vm_template].nil? && !allow_no_vm_template
            new_role = {
              :cardinality => role[:min_vms] || 1,
              :elasticity_policies => [],
              :scheduled_policies => []
            }.merge(role)
            if role[:vm_template].is_a?(String)
              if id_cache[role[:vm_template]].nil?
                template_from_one = driver.one.get_resource(:template, :name => role[:vm_template])
                fail "Could not find a template with the name '#{role[:vm_template]}'" if template_from_one.nil?
                id = template_from_one.to_hash['VMTEMPLATE']['ID'].to_i
                id_cache[role[:vm_template]] = id
                new_role[:vm_template] = id
              else
                new_role[:vm_template] = id_cache[role[:vm_template]]
              end
            end
            new_role
          end
          template
        end

        # Helper for merge_template
        def special_merge_hash(base_hash, new_hash, delete_roles = true)
          keys_to_delete = []
          merged = base_hash.merge(new_hash) do |key, oldval, newval|
            # This is probably a redundant fail ...
            fail 'Class of values in the templates must remain the same. If you want to delete an entry, set it to nil.' unless
              oldval.is_a?(newval.class) || newval.is_a?(NilClass) || key == :vm_template
            case newval
            when NilClass
              keys_to_delete.push(key)
              nil
            when Array
              if key == :roles
                new_array = []
                old_as_hash = Hash[oldval.collect { |role| [role[:name], role] }]

                newval.each do |role|
                  if role.key?(:delete_role) && delete_roles
                    old_as_hash.delete(role[:name])
                    next
                  end
                  fail 'All roles must have a name.' if role[:name].nil?
                  if old_as_hash.key?(role[:name])
                    new_array.push(special_merge_hash(old_as_hash[role[:name]], role))
                    old_as_hash.delete(role[:name])
                  else
                    new_array.push(role)
                  end
                end

                new_array + old_as_hash.values
              else
                newval
              end
            when Hash
              special_merge_hash(oldval, newval)
            else
              newval
            end
          end
          keys_to_delete.each { |key| merged.delete(key) }
          merged
        end

        # Performs a overwrite-merge of two OneFlow templates, any key with nil value will be deleted
        def merge_template(base_tpl, new_tpl, overwrite_name = false, delete_roles = true)
          fail 'Service template name changing is not supported.' if new_tpl.key?(:name) && !overwrite_name && base_tpl[:name] != new_tpl[:name]
          special_merge_hash(base_tpl, new_tpl, delete_roles)
        end

        # Issues warnings for a failsafe override
        def override_failsafe_warn
          Chef::Log.warn('You have chose to use an action that is untested / partially implemented.')
          Chef::Log.warn('Specifically, the driver will send the appropriate POST request to the Flow API')
          Chef::Log.warn('But the driver will not verify that the action ran successfully, or ran at all.')
          Chef::Log.warn('Moreover, the driver will not wait for the action complete, as in, the action will')
          Chef::Log.warn('run asynchronously, meaning dependent actions after this one may fail.')
          Chef::Log.warn('Use at your own risk. Please report any issues.')
        end

        # Validate the attributes period and number
        def validate_role_action(period, number)
          fail "Make sure 'period' >= 0" if !period.empty? && period.to_i < 0
          fail "Make sure 'number' >= 0" if !number.empty? && number.to_i < 0
        end

        # REST call to flow api
        def request(method, url, payload = '{}')
          case payload
          when Hash
            RestClient::Request.execute(
              method: method,
              url: @flow_url + url,
              user: @username,
              password: @password,
              payload: payload.to_json
            )
          when String
            JSON.parse(payload)
            RestClient::Request.execute(
              method: method,
              url: @flow_url + url,
              user: @username,
              password: @password,
              payload: payload
            )
          else
            fail 'Payload must be hash or json string.'
          end
        rescue JSON::ParserError
          fail 'Malformed json string.'
        rescue RestClient::ResourceNotFound, RestClient::BadRequest, RestClient::InternalServerError => e
          raise OpenNebulaException, "#{e}\nThere's a problem. Here's a hint:\n#{e.response}"
        end

        # Converts all arrays to sets
        def recursive_array_to_set(object)
          case object
          when Array
            return object.map { |e| recursive_array_to_set(e) }.to_set
          when Hash
            object.each do |key, value|
              object[key] = recursive_array_to_set(value)
            end
            return object
          else
            return object
          end
        end

        # Checks if two hashes are equal, ignore array order
        def hash_eq?(hash1, hash2)
          recursive_array_to_set(Marshal.load(Marshal.dump(hash1))) == recursive_array_to_set(Marshal.load(Marshal.dump(hash2)))
        end

        # Returns all of the IDs of a service or template that matches a name
        def get_ids(type, name)
          response = request(:get, type == :template ? '/service_template' : '/service')
          ids = []
          data = JSON.parse(response, :symbolize_names => true)
          return [] if data[:DOCUMENT_POOL][:DOCUMENT].nil?
          data[:DOCUMENT_POOL][:DOCUMENT].each { |e| ids.push(e[:ID].to_i) if e[:NAME] == name }
          ids
        end

        # Gets a single ID of a service or template, fails if there's not exactly 1, or returns nil if there 0 and nil_if_none
        def get_unique_id(type, name, nil_if_none = false)
          matches = get_ids(type, name)
          if matches.length == 0
            return nil if nil_if_none
            fail "There are no OneFlow #{type}s with the name '#{name}'"
          elsif matches.length > 1
            fail "There are multiple OneFlow #{type}s with the name '#{name}'"
          else
            matches[0]
          end
        end

        # Check if a service or template exists
        def exists?(type, name)
          get_ids(type, name).length == 0 ? false : true
        end

        # Gets permission of service or template
        def get_permissions(type, id)
          id = id.to_s
          response = request(:get, type == :template ? '/service_template' : '/service')
          data = JSON.parse(response, :symbolize_names => true)[:DOCUMENT_POOL][:DOCUMENT]
          data.each do |tpl|
            next unless tpl[:ID] == id
            perms = tpl[:PERMISSIONS]
            mode = ''
            [:OWNER_U, :OWNER_M, :OWNER_A, :GROUP_U, :GROUP_M, :GROUP_A, :OTHER_U, :OTHER_M, :OTHER_A].each { |m| mode += perms[m] }
            return mode.to_i(2).to_s(8)
          end
          fail "#{type} with id=#{id} does not exist."
        end

        # Wrapper for get_ids
        def get_template_ids(name)
          get_ids(:template, name)
        end

        # Wrapper for get_unique_id
        def get_unique_template_id(name, nil_if_none = false)
          get_unique_id(:template, name, nil_if_none)
        end

        # Wrapper for exists?
        def template_exists?(name)
          exists?(:template, name)
        end

        # Gets a template given a template ID
        def get_template(id)
          response = request(:get, "/service_template/#{id}")
          JSON.parse(response, :symbolize_names => true)[:DOCUMENT][:TEMPLATE][:BODY]
        end

        # Wrapper for get_permissions
        def get_template_permissions(id)
          get_permissions(:template, id)
        end

        # Wrapper for get_ids
        def get_service_ids(name)
          get_ids(:service, name)
        end

        # Wrapper for get_unique_id
        def get_unique_service_id(name, nil_if_none = false)
          get_unique_id(:service, name, nil_if_none)
        end

        # Wrapper for exists?
        def service_exists?(name)
          exists?(:service, name)
        end

        # Wrapper for get_permissions
        def get_service_permissions(id)
          get_permissions(:service, id)
        end

        # Returns the template of a service with runtime content removed
        def get_reduced_service_template(id)
          response = request(:get, "/service/#{id}")
          template_from_one = JSON.parse(response, :symbolize_names => true)[:DOCUMENT][:TEMPLATE][:BODY]
          service_name = template_from_one[:name]
          [:log, :name, :state, :custom_attrs_values].each { |key| template_from_one.delete(key) }
          template_from_one[:roles].each do |role|
            role[:nodes].each do |node|
              unless node[:running]
                Chef::Log.warn("A node in role '#{node[:vm_info][:VM][:USER_TEMPLATE][:ROLE_NAME]}' of service '#{service_name}' is not normal!")
              end
            end
            [:cardinality, :nodes, :state, :disposed_nodes, :cooldown_end, :last_vmname, :user_inputs_values, :vm_template_contents].each { |key| role.delete(key) }
          end
          template_from_one
        end

        # Gets the state of a service
        # 0 => PENDING, 1 => DEPLOYING, 2 => RUNNING, 3 => UNDEPLOYING, 5 => DONE,
        # 7 => FAILED_DEPLOYING, 8 => SCALING, 9 => FAILED_SCALING, 10 => COOLDOWN
        def get_service_state(id)
          response = request(:get, "/service/#{id}")
          JSON.parse(response, :symbolize_names => true)[:DOCUMENT][:TEMPLATE][:BODY][:state].to_i
        end

        # Returns a role of a service
        def get_role(service_id, role_name)
          response = request(:get, "/service/#{service_id}")
          JSON.parse(response, :symbolize_names => true)[:DOCUMENT][:TEMPLATE][:BODY][:roles].each { |role| return role if role[:name] == role_name }
          fail "#{role_name} doesn't seem to exist!"
        end

        # Returns the state of a role
        # It seems that regardless of the state of the VMs, the state of a role will be RUNNING
        # So I will be doing a workaround where I will return that it's SUSPENDED if all of the VMs are SUSPENDED
        # nil => role doesn't exist, -1 => there are no VMs, 1 => PENDING,
        # 3 => RUNNING, 4 => STOPPED, 5 => SUSPENDED, 8 => POWEROFF, 9 => UNDEPLOYED
        def get_role_state(id, role_name)
          role = get_role(id, role_name)
          return -1 if role[:cardinality].to_i == 0
          state_counter = { 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 8 => 0, 9 => 0 }
          role[:nodes].each do |node|
            state = node[:vm_info][:VM][:STATE].to_i
            fail "UNSUPPORTED STATE #{state}" if state_counter[state].nil?
            state_counter[state] += 1
            return state if state_counter[state] == role[:cardinality].to_i
          end
          state_counter # Return the hash of counters if states are staggered
        end

        # Gets the cardinality of a role
        def get_role_cardinality(id, role_name)
          get_role(id, role_name)[:cardinality].to_i
        end

        # Creates a post request for an action
        def perform_action(url, action, params)
          request(:post, url, "{\"action\":{\"perform\":\"#{action}\",\"params\":#{params.to_json}}}")
        end

        ####################
        # TEMPLATE ACTIONS #
        ####################

        # Creates a template in ONE
        def create_template(payload)
          request(:post, '/service_template', payload)
          true
        end

        # Updates a template in ONE
        def update_template(template_name, payload)
          request(:put, "/service_template/#{get_unique_template_id(template_name)}", payload)
        end

        # Deletes a template in ONE
        def delete_template(template_id)
          request(:delete, "/service_template/#{template_id}")
        end

        # Spawns a service from a template
        def instantiate_template(tid, template, service_name)
          url = "/service_template/#{tid}/action"
          perform_action(url, 'instantiate', :merge_template => template)

          service_id = get_unique_service_id(service_name)
          state = nil
          while state != SERVICE_RUNNING
            Chef::Log.info("Waiting for RUNNING for '#{service_name}'")
            sleep(15)
            state = get_service_state(service_id)
            fail "Service failed to deploy  ...\nThere's probably something wrong with your template." if state == SERVICE_FAILED_DEPLOYING
          end
        end

        # Modifies the permissions of a template
        def chmod_template(template_id, octet)
          url = "/service_template/#{template_id}/action"
          perform_action(url, 'chmod', :octet => octet)
        end

        ###################
        # SERVICE ACTIONS #
        ###################

        # Deletes a service in ONE
        def delete_service(service_id)
          request(:delete, "/service/#{service_id}")
        end

        # Performs shutdown on an entire service
        def shutdown_service(service_name, sid)
          url = "/service/#{sid}/action"
          perform_action(url, 'shutdown', {})

          state = nil
          while state != SERVICE_DONE
            Chef::Log.info("Waiting for SHUTDOWN COMPLETE for '#{service_name}'")
            sleep(15)
            state = get_service_state(sid)
            fail 'Service failed to shutdown ...' unless Set[SERVICE_RUNNING, SERVICE_UNDEPLOYING, SERVICE_DONE].include?(state)
          end
        end

        # Performs the recover action on a service
        def recover_service(service_id, service_name)
          url = "/service/#{service_id}/action"
          perform_action(url, 'recover', {})

          state = nil
          while state != SERVICE_RUNNING
            Chef::Log.info("Waiting for RUNNING for '#{service_name}'")
            sleep(15)
            state = get_service_state(service_id)
            fail 'Service failed to recover ...' if state == SERVICE_FAILED_DEPLOYING
          end
        end

        # Modifies the permissions of a service
        def chmod_service(sid, octet)
          url = "/service/#{sid}/action"
          perform_action(url, 'chmod', :octet => octet)
        end

        # Performs an action on a role
        def role_action(sid, role_name, action, period, number, desired_state = nil)
          validate_role_action(period, number)
          url = "/service/#{sid}/role/#{role_name}/action"
          perform_action(url, action, :period => period, :number => number)

          state = nil
          while state != desired_state
            Chef::Log.info("Waiting for #{action} to complete")
            sleep(15)
            state = get_role_state(sid, role_name)
            fail "#{action} failed. Got unsupported state #{state}" unless Set[ROLE_NO_VMS, ROLE_PENDING, ROLE_RUNNING, ROLE_STOPPED, ROLE_SUSPENDED, ROLE_POWEROFF, ROLE_UNDEPLOYED].include?(state)
          end
        end

        # Scales a role to a new cardinality
        def role_scale(service_id, service_name, role_name, card, force)
          request(:put, "/service/#{service_id}/role/#{role_name}", :cardinality => card, :force => force)

          state = nil
          while state != SERVICE_RUNNING
            Chef::Log.info("Waiting for RUNNING for '#{service_name}'")
            sleep(15)
            state = get_service_state(service_id)
            fail 'Service failed to scale ...' if state == SERVICE_FAILED_SCALING
          end
        end
      end
    end
  end
end
