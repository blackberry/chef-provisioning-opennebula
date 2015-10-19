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
      action_handler.perform_action "Allocating image '#{new_resource.name}'" do
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
      end
    else
      action_handler.report_progress "Image '#{new_resource.name}' already exists - nothing to do"
    end
    img
  end

  action :create do
    img = action_allocate
    case img.state_str
    when 'INIT', 'LOCKED'
      action_handler.perform_action "Waiting for image '#{new_resource.name}' to be READY" do
        current_driver.one.wait_for_img(new_resource.name, img.id)
      end
    when 'READY', 'USED', 'USED_PERS'
      action_handler.report_progress "Image '#{new_resource.name}' is already in #{img.state_str} state - nothing to do"
    else
      raise "Image #{new_resource.name} is in unexpected state '#{img.state_str}'"
    end
  end

  action :destroy do
    new_driver = get_driver
    img = new_driver.one.get_resource('img', {:name => new_resource.name})
    if !img.nil?
      action_handler.perform_action "Deleting image '#{new_resource.name}'" do
        rc = img.delete
        raise "Failed to delete image '#{new_resource.name}' : #{rc.message}" if OpenNebula.is_error?(rc)
      end
    else
      action_handler.report_progress "Image '#{new_resource.name}' does not exist - nothing to do"
    end
  end

  action :attach do
    raise "Missing attribute 'machine_id'" if !new_resource.machine_id
    new_driver = get_driver
    img = new_driver.one.get_resource('img', {:name => new_resource.name})
    vm = new_driver.one.get_resource('vm', {new_resource.machine_id.is_a?(Integer) ? :id : :name => new_resource.machine_id})

    if !img.nil? and !vm.nil? 
      action_handler.perform_action "Attach disk #{new_resource.name} to #{vm.name}" do
        disk_hash = img.to_hash
        disk_tpl = <<-EOT
DISK = [
  IMAGE = #{disk_hash['IMAGE']['NAME']},
  IMAGE_UNAME = #{disk_hash['IMAGE']['UNAME']}
]
EOT
        disk_id = new_driver.one.get_disk_id(vm, disk_hash['IMAGE']['NAME'])
        if !disk_id.nil?
          action_handler.report_progress "Disk is already attached" if !disk_id.nil?
        else disk_id.nil?
          action_handler.report_progress "Disk not attached. Attaching..."
          rc = vm.disk_attach(disk_tpl)
          new_driver.one.wait_for_vm(vm.id)
          raise "Failed to attach disk to VM '#{vm.name}': #{rc.message}" if OpenNebula.is_error?(rc)
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
      action_handler.report_progress "Snapshot image '#{new_resource.name}' already exists - nothing to do"
    else
      raise "Failed to create snapshot - VM '#{new_resource.machine_id}' does not exist" if vm.nil?

      action_handler.perform_action "Creating snapshot from '#{new_resource.machine_id}'" do
        disk_id = new_resource.disk_id.is_a?(Integer) ? new_resource.disk_id : new_driver.one.get_disk_id(vm, new_resource.disk_id)
        raise "No disk '#{new_resource.disk_id}' found on '#{vm.name}'" if disk_id.nil?

        new_img = vm.disk_snapshot(disk_id, new_resource.name, "", true)
        raise "Failed to create snapshot '#{new_resource.name}': #{new_img.message}" if OpenNebula.is_error?(new_img)

        new_img = new_driver.one.wait_for_img(new_resource.name, new_img)
        if new_resource.persistent
          action_handler.report_progress "Making image '#{new_resource.name}' persistent"
          new_img.persistent 
        end
      end
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
