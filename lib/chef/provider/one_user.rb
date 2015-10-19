# Copyright 2015, BlackBerry, Inc.
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

class Chef::Provider::OneUser < Chef::Provider::LWRPBase
  use_inline_resources

  provides :one_user
  
  attr :current_user

  def action_handler
    @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
  end

  def exists?(filter)
    new_driver = get_driver
    @current_user = new_driver.one.get_resource('user', filter)
    Chef::Log.debug("user '#{filter}' exists: #{!@current_user.nil?}")
    !@current_user.nil?
  end

  action :create do
    raise "Missing attribute 'password'" if !@new_resource.password

    if exists?({:name => @new_resource.name})
      action_handler.report_progress "user '#{@new_resource.name}' already exists - nothing to do"
    else
      action_handler.perform_action "create user '#{@new_resource.name}'" do
        user = OpenNebula::User.new(OpenNebula::User.build_xml, @client)
        rc = user.allocate(@new_resource.name, @new_resource.password) if !OpenNebula.is_error?(vnet)
        Chef::Log.debug(template_str)
        raise "failed to create vnet '#{@new_resource.name}': #{vnet.message}" if OpenNebula.is_error?(vnet)
        @new_resource.updated_by_last_action(true)
      end
    end
  end

  action :delete do
    if exists?({:id => @new_resource.user_id, :name => @new_resource.name})
      action_handler.perform_action "deleted user '#{new_resource.name}' (#{@current_user.id})" do
        rc = @current_user.delete
        raise "failed to delete user '#{@new_resource.name}': #{rc.message}" if OpenNebula.is_error?(rc)
        @new_resource.updated_by_last_action(true)
      end
    else
      action_handler.report_progress "user '#{new_resource.name}' does not exists - nothing to do"
    end
  end

  action :update do
    if exists?(({:id => @new_resource.user_id, :name => @new_resource.name}))
      raise "':template' or ':template_file' attribute missing" if !@new_resource.template and !@new_resource.template_file
      hash = @current_user.to_hash
      tpl = new_driver.one.create_template(@new_resource.template) if @new_resource.template
      tpl = ::File.read(@new_resource.template_file) if @new_resource.template_file

      rc = @current_user.update(tpl, true)
      raise "failed to update user '#{@new_resource.name}': #{rc.message}" if OpenNebula.is_error?(rc)
    else
      raise "user '#{new_resource.name}' does not exists"
    end
  end

  protected

  def get_driver
    if current_driver && current_driver.driver_url != new_driver.driver_url
      raise "Cannot move '#{machine_spec.name}' from #{current_driver.driver_url} to #{new_driver.driver_url}: machine moving is not supported.  Destroy and recreate."
    end
    if !new_driver
      raise "Driver not specified for one_image #{new_resource.name}"
    end
    new_driver
  end

  def new_driver
    run_context.chef_provisioning.driver_for(new_resource.driver)
  end

  def current_driver
    if run_context.chef_provisioning.current_driver
      run_context.chef_provisioning.driver_for(run_context.chef_provisioning.current_driver)
    end
  end
end
