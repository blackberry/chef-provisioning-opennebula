
class Chef::Provider::OneTemplate < Chef::Provider::LWRPBase
  use_inline_resources
  
  def action_handler
    @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
  end

  action :create do
    raise "Missing attribute 'template_file' or 'template'" if !new_resource.template_file and !new_resource.template
    new_driver = get_driver
    tpl = new_driver.one.get_resource('tpl', {:name => new_resource.name})

    if !tpl.nil?
      action_handler.report_progress "Template #{new_resource.name} already exists - nothing to do"
    else
      action_handler.perform_action "Creating template #{new_resource.name}" do
        template_str = File.read(new_resource.template_file) if new_resource.template_file
        template_str = new_driver.one.create_template(new_resource.template) if new_resource.template
        template_str << "\nNAME=\"#{new_resource.name}\""
        tpl = new_driver.one.allocate_template(new_resource.name, template_str)
      end
    end
  end

  action :delete do
    new_driver = get_driver
    tpl = new_driver.one.get_resource('tpl', {:name => new_resource.name})

    if tpl.nil?
      action_handler.report_progress "Template #{new_resource.name} does not exists - nothing to do"
    else
      action_handler.perform_action "Deleting template #{new_resource.name}" do
        tpl.delete
      end
    end
  end

  action :instantiate do
    raise "Only one of 'instances' or 'count' attributes can be specified" if new_resource.count and new_resource.instances
    new_driver = get_driver
    tpl = new_driver.one.get_resource('tpl', {:name => new_resource.name})

    if tpl.nil?
      raise "Failed to instantiate template #{new_resource.name} - template does not exists"
    else
      action_handler.perform_action "Creating instances from template #{new_resource.name}" do
        if new_resource.instances 
          instance_array = new_resource.instances.split(',') if new_resource.instances.is_a?(String)
          instance_array = new_resource.instances if new_resource.instances.is_a?(Array)
          instance_array.each { |inst|
            # check fi this name already exists
            vm = new_driver.one.get_resource('vm', {:name => inst})
            if !vm.nil?
              action_handler.report_progress "Instance with name '#{inst}' already exists - skipping"
            else
              rc = tpl.instantiate(inst)
              raise "Failed to create instance from template #{new_resource.name}: #{rc.message}" if OpenNebula.is_error?(rc) 
              action_handler.report_progress "Created instance: #{inst} - ID: #{rc}"
            end
          }
        else 
          new_resource.count.times {            
            rc = tpl.instantiate
            raise "Failed to create instance from template #{new_resource.name}: #{rc.message}" if OpenNebula.is_error?(rc) 
            action_handler.report_progress "Created instance with ID: #{rc}"
          }
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
