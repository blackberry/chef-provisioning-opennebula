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

class Chef::Provider::OneImage < Chef::Provider::LWRPBase
  use_inline_resources

  provides :one_image

  attr :image

  def whyrun_supported?
    true
  end
  
  def load_current_resource
  end

  def action_handler
    @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
  end

  def exists?
    new_driver = get_driver
    @image = new_driver.one.get_resource('img', {:name => new_resource.name})
    !@image.nil?
  end

  action :allocate do
    if exists?
      action_handler.report_progress "image '#{new_resource.name}' already exists - nothing to do"
    else
      raise "'size' must be specified" if !new_resource.size
      raise "'datastore_id' must be specified" if !new_resource.datastore_id

      action_handler.perform_action "allocated image '#{new_resource.name}'" do
        @image = new_driver.one.allocate_img(
          new_resource.name, 
          new_resource.size, 
          new_resource.datastore_id, 
          new_resource.type || 'OS', 
          new_resource.fs_type || 'ext2', 
          new_resource.img_driver || 'qcow2', 
          new_resource.prefix || 'vd',
          new_resource.persistent || false)
        Chef::Log.info("Image '#{new_resource.name}' allocate in initial state #{@image.state_str}")
        @new_resource.updated_by_last_action(true)
      end
    end
    @image
  end

  action :create do
    @image = action_allocate
    case @image.state_str
    when 'INIT', 'LOCKED'
      action_handler.perform_action "wait for image '#{new_resource.name}' to be READY" do
        current_driver.one.wait_for_img(new_resource.name, @image.id)
        @new_resource.updated_by_last_action(true)
      end
    when 'READY', 'USED', 'USED_PERS'
      action_handler.report_progress "image '#{new_resource.name}' is already in #{@image.state_str} state - nothing to do"
    else
      raise "Image #{new_resource.name} is in unexpected state '#{@image.state_str}'"
    end
  end

  action :destroy do
    if exists?
      action_handler.perform_action "deleted image '#{new_resource.name}'" do
        rc = @image.delete
        raise "Failed to delete image '#{new_resource.name}' : #{rc.message}" if OpenNebula.is_error?(rc)
        while !new_driver.one.get_resource('img', {:name => new_resource.name}).nil? do
          Chef::Log.debug("Waiting for delete image to finish...")
          sleep 1
        end
        @new_resource.updated_by_last_action(true)
      end      
    else
      action_handler.report_progress "image '#{new_resource.name}' does not exist - nothing to do"
    end
  end

  action :attach do
    raise "Missing attribute 'machine_id'" if !new_resource.machine_id
    raise "Failed to attach disk - image '#{new_resource.name}' does not exist" if !exists?

    vm = new_driver.one.get_resource('vm', {new_resource.machine_id.is_a?(Integer) ? :id : :name => new_resource.machine_id})
    raise "Failed to attach disk - VM '#{new_resource.machine}' does not exist" if vm.nil?
      action_handler.perform_action "attached disk #{new_resource.name} to #{vm.name}" do
        disk_hash = @image.to_hash
        disk_tpl = "DISK = [ "
        disk_tpl << " IMAGE = #{disk_hash['IMAGE']['NAME']}, IMAGE_UNAME = #{disk_hash['IMAGE']['UNAME']}"
        disk_tpl << ", TARGET = #{new_resource.target}" if new_resource.target
        disk_tpl << ", DEV_PREFIX = #{new_resource.prefix}" if new_resource.prefix 
        disk_tpl << ", CACHE = #{new_resource.cache}" if new_resource.cache
        disk_tpl << "]"

        disk_id = new_driver.one.get_disk_id(vm, disk_hash['IMAGE']['NAME'])
        if !disk_id.nil?
          action_handler.report_progress "disk is already attached" if !disk_id.nil?
        else disk_id.nil?
          action_handler.report_progress "disk not attached, attaching..."
          rc = vm.disk_attach(disk_tpl)
          new_driver.one.wait_for_vm(vm.id)
          raise "Failed to attach disk to VM '#{vm.name}': #{rc.message}" if OpenNebula.is_error?(rc)
          @new_resource.updated_by_last_action(true)
        end
      end
  end

  action :snapshot do
    raise "Missing attribute 'machine_id'" if !new_resource.machine_id
    if exists?
      action_handler.report_progress "snapshot image '#{new_resource.name}' already exists - nothing to do"
    else
      vm = new_driver.one.get_resource('vm', {new_resource.machine_id.is_a?(Integer) ? :id : :name => new_resource.machine_id})
      raise "Failed to create snapshot - VM '#{new_resource.machine_id}' does not exist" if vm.nil?
      action_handler.perform_action "created snapshot from '#{new_resource.machine_id}'" do
        disk_id = new_resource.disk_id.is_a?(Integer) ? new_resource.disk_id : new_driver.one.get_disk_id(vm, new_resource.disk_id)
        raise "No disk '#{new_resource.disk_id}' found on '#{vm.name}'" if disk_id.nil?

        @image = vm.disk_snapshot(disk_id, new_resource.name, "", true)
        raise "Failed to create snapshot '#{new_resource.name}': #{@image.message}" if OpenNebula.is_error?(@image)

        @image = new_driver.one.wait_for_img(new_resource.name, @image)
        if new_resource.persistent
          action_handler.report_progress "make image '#{new_resource.name}' persistent"
          @image.persistent 
        end
        @new_resource.updated_by_last_action(true)
      end      
    end
  end

  action :upload do
    raise "'datastore_id' is required" if !new_resource.datastore_id
    raise "'image_file' is required" if !new_resource.image_file
    raise "image_file #{new_resource.image_file} does not exist" if !::File.exists? new_resource.image_file

    file_url = "http://#{node['ipaddress']}/#{::File.basename(@new_resource.image_file)}"
    description = @new_resource.description || "#{@new_resource.name} image"
    image_driver = @new_resource.img_driver || 'qcow2'

    if exists?
      if @image.name == @new_resource.name and 
         @image['PATH'] == file_url and 
         @image['TEMPLATE/DRIVER'] == image_driver and 
         @image['TEMPLATE/DESCRIPTION'] == description and 
         @image['DATASTORE_ID'] == @new_resource.datastore_id.to_s
        action_handler.report_progress("image '#{@new_resource.name}' (ID: #{@image.id}) already exists - nothing to do")
      else
        raise "image '#{new_resource.name}' already exists, but it is not the same image"
      end
    else
      action_handler.perform_action "upload image '#{@new_resource.image_file}'" do
        begin
          pid = Process.spawn("sudo python -m SimpleHTTPServer 80", :chdir => ::File.dirname(@new_resource.image_file), STDOUT => "/dev/null", STDERR => "/dev/null", :pgroup=>true)
          raise "Failed to start 'SimpleHTTPServer'" if pid.nil?
          new_driver.one.upload_img(
            @new_resource.name,
            @new_resource.datastore_id,
            file_url,
            image_driver,
            description,
            @new_resource.type,
            @new_resource.prefix,
            @new_resource.persistent,
            @new_resource.public,
            @new_resource.target,
            @new_resource.disk_type,
            @new_resource.source,
            @new_resource.size,
            @new_resource.fs_type)

          @new_resource.updated_by_last_action(true)
        ensure
          system("sudo kill -9 -#{pid}")
        end
      end
    end
  end

  action :download do
    new_driver = get_driver

    action_handler.perform_action "downloaded image '#{@new_resource.image_file}" do
      download_url = ENV['ONE_DOWNLOAD'] || @new_resource.download_url
      raise "'download_url' is a required attribute.  You can get the value for 'download_url' by loging into your OpenNebula CLI and reading the ONE_DOWNLOAD environment variable" if download_url.nil?
      image = new_driver.one.get_resource('img', !@new_resource.image_id.nil? ? {:id => @new_resource.image_id } : {:name => @new_resource.name}) 
      raise "Image 'NAME: #{@new_resource.name}/ID: #{@new_resource.image_id}' does not exist" if image.nil?
      local_path = @new_resource.image_file || ::File.join(Chef::Config[:file_cache_path], "#{@new_resource.name}.qcow2")
      raise "Will not overwrite an existing file: #{local_path}" if ::File.exist?(local_path)
      command = "curl -o #{local_path} #{download_url}/#{::File.basename(::File.dirname(image['SOURCE']))}/#{::File.basename(image['SOURCE'])}"
      rc = system(command)
      raise rc if rc.nil?
      raise "ERROR: #{rc}" if !rc
      system("chmod 777 #{local_path}")
      Chef::Log.info("Image downloaded from OpenNebula to: #{local_path}")
      @new_resource.updated_by_last_action(true)
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
