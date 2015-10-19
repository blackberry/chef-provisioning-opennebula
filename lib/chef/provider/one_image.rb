class Chef::Provider::OneImage < Chef::Provider::LWRPBase
  use_inline_resources

  def whyrun_supported?
    true
  end
  
  def load_current_resource
  end

  def action_handler
    @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
  end

  action :allocate do
    new_driver = get_driver
    img = new_driver.one.get_resource('img', {:name => new_resource.name})
    if img.nil?
      action_handler.perform_action "allocated image '#{new_resource.name}'" do
        img = new_driver.one.allocate_img(
          new_resource.name, 
          new_resource.size, 
          new_resource.datastore_id, 
          new_resource.type, 
          new_resource.fs_type, 
          new_resource.img_driver, 
          new_resource.prefix,
          new_resource.persistent)
        Chef::Log.info("Image '#{new_resource.name}' allocate in initial state #{img.state_str}")
        @new_resource.updated_by_last_action(true)
      end
    else
      action_handler.report_progress "image '#{new_resource.name}' already exists - nothing to do"
    end
    img
  end

  action :create do
    img = action_allocate
    case img.state_str
    when 'INIT', 'LOCKED'
      action_handler.perform_action "wait for image '#{new_resource.name}' to be READY" do
        current_driver.one.wait_for_img(new_resource.name, img.id)
        @new_resource.updated_by_last_action(true)
      end
    when 'READY', 'USED', 'USED_PERS'
      action_handler.report_progress "image '#{new_resource.name}' is already in #{img.state_str} state - nothing to do"
    else
      raise "Image #{new_resource.name} is in unexpected state '#{img.state_str}'"
    end
  end

  action :destroy do
    new_driver = get_driver
    img = new_driver.one.get_resource('img', {:name => new_resource.name})
    if !img.nil?
      action_handler.perform_action "deleted image '#{new_resource.name}'" do
        rc = img.delete
        raise "Failed to delete image '#{new_resource.name}' : #{rc.message}" if OpenNebula.is_error?(rc)
        @new_resource.updated_by_last_action(true)
      end
    else
      action_handler.report_progress "image '#{new_resource.name}' does not exist - nothing to do"
    end
  end

  action :attach do
    raise "Missing attribute 'machine_id'" if !new_resource.machine_id
    new_driver = get_driver
    img = new_driver.one.get_resource('img', {:name => new_resource.name})
    vm = new_driver.one.get_resource('vm', {new_resource.machine_id.is_a?(Integer) ? :id : :name => new_resource.machine_id})

    if !img.nil? and !vm.nil? 
      action_handler.perform_action "attached disk #{new_resource.name} to #{vm.name}" do
        disk_hash = img.to_hash
        disk_tpl = <<-EOT
DISK = [
  IMAGE = #{disk_hash['IMAGE']['NAME']},
  IMAGE_UNAME = #{disk_hash['IMAGE']['UNAME']}
]
EOT
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
    else
      raise "Failed to attach disk - Image '#{new_resource.name}' does not exist" if img.nil?
      raise "Failed to attach disk - VM '#{new_resource.machine}' does not exist" if vm.nil?
    end
  end

  action :snapshot do
    raise "Missing attribute 'machine_id'" if !new_resource.machine_id
    new_driver = get_driver
    vm = nil
    vm = new_driver.one.get_resource('vm', {new_resource.machine_id.is_a?(Integer) ? :id : :name => new_resource.machine_id})
    img = new_driver.one.get_resource('img', {:name => new_resource.name})
    
    if !img.nil?
      action_handler.report_progress "snapshot image '#{new_resource.name}' already exists - nothing to do"
    else
      raise "Failed to create snapshot - VM '#{new_resource.machine_id}' does not exist" if vm.nil?

      action_handler.perform_action "created snapshot from '#{new_resource.machine_id}'" do
        disk_id = new_resource.disk_id.is_a?(Integer) ? new_resource.disk_id : new_driver.one.get_disk_id(vm, new_resource.disk_id)
        raise "No disk '#{new_resource.disk_id}' found on '#{vm.name}'" if disk_id.nil?

        new_img = vm.disk_snapshot(disk_id, new_resource.name, "", true)
        raise "Failed to create snapshot '#{new_resource.name}': #{new_img.message}" if OpenNebula.is_error?(new_img)

        new_img = new_driver.one.wait_for_img(new_resource.name, new_img)
        if new_resource.persistent
          action_handler.report_progress "make image '#{new_resource.name}' persistent"
          new_img.persistent 
        end
        @new_resource.updated_by_last_action(true)
      end
    end
  end

  action :upload do
    raise "'datastore_id' is required" if @new_resource.datastore_id.nil?
    raise "'image_file' is required" if @new_resource.image_file.nil?
    raise "image_file #{@new_resource.image_file} does not exist" if !::File.exists? @new_resource.image_file

    new_driver = get_driver

    action_handler.perform_action "uploaded image '#{@new_resource.image_file}'" do
      file_url = "http://#{node['ipaddress']}/#{::File.basename(@new_resource.image_file)}"
      description = @new_resource.description || "#{@new_resource.name} image"
      driver = @new_resource.img_driver || 'qcow2'
      
      begin
        pid = Process.spawn("sudo python -m SimpleHTTPServer 80", :chdir => ::File.dirname(@new_resource.image_file), STDOUT => "/dev/null", STDERR => "/dev/null", :pgroup=>true)
        raise "Failed to start 'SimpleHTTPServer'" if pid.nil?

        new_driver.one.upload_img(
          @new_resource.name,
          @new_resource.datastore_id,
          file_url,
          driver,
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
