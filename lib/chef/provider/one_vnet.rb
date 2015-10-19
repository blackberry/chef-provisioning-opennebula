
class Chef::Provider::OneVnet < Chef::Provider::LWRPBase
  use_inline_resources

  attr :current_vnet

  def action_handler
    @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
  end

  def exists?(filter)
    new_driver = get_driver
    @current_vnet = new_driver.one.get_resource('vnet', filter)
    Chef::Log.debug("VNET '#{filter}' exists: #{!@current_vnet.nil?}")
    !@current_vnet.nil?
  end

  action :create do
    raise "Missing attribute 'template_file'" if !@new_resource.template_file
    raise "Missing attribute 'cluster_id'" if !@new_resource.cluster_id

    if exists?({:name => @new_resource.name})
      action_handler.report_progress "vnet '#{@new_resource.name}' already exists - nothing to do"
    else
      action_handler.perform_action "created vnet '#{@new_resource.name}' from '#{@new_resource.template_file}'" do
        template_str = ::File.read(@new_resource.template_file) + "\nNAME=\"#{@new_resource.name}\""
        vnet = OpenNebula::Vnet.new(OpenNebula::Vnet.build_xml, @client)
        vnet = vnet.allocate(template_str, @new_resource.cluster_id) if !OpenNebula.is_error?(vnet)
        Chef::Log.debug(template_str)
        raise "failed to create vnet '#{@new_resource.name}': #{vnet.message}" if OpenNebula.is_error?(vnet)
        @new_resource.updated_by_last_action(true)
      end
    end
  end

  action :delete do
    if exists?({:id => @new_resource.vnet_id, :name => @new_resource.name})
      action_handler.perform_action "deleted vnet '#{new_resource.name}' (#{@current_vnet.id})" do
        rc = @current_vnet.delete
        raise "failed to delete vnet '#{@new_resource.name}': #{rc.message}" if OpenNebula.is_error?(rc)
        @new_resource.updated_by_last_action(true)
      end
    else
      action_handler.report_progress "vnet '#{new_resource.name}' does not exists - nothing to do"
    end
  end

  action :reserve do
    raise "Missing attribute 'network'" if !@new_resource.network

    if exists?({:name => @new_resource.name})
      hash = @current_vnet.to_hash
      ar_pool = [hash['VNET']['AR_POOL']].flatten
      Chef::Log.debug(@current_vnet.to_hash)
      same = false
      if @new_resource.ar_id and @new_resource.ar_id > -1
        ar_pool.each { |ar| 
          same = true if ar['AR']['AR_ID'] == @new_resource.ar_id.to_s and ar['AR']['SIZE'].to_i == @new_resource.size
        }
      else
        same = ar_pool[0]['AR']['SIZE'].to_i == @new_resource.size
      end
      if same
        action_handler.report_progress "vnet '#{@new_resource.name}' already exists - nothing to do"
      else
        raise "vnet '#{@new_resource.name}' exists with different configuration"
      end
    else
      raise "parent network '#{@new_resource.network}' does not exist" if !exists?({:id => @new_resource.network})
      action_handler.perform_action "reserved vnet '#{@new_resource.name}'" do
        rc = @current_vnet.reserve(@new_resource.name, @new_resource.size.to_s, @new_resource.ar_id.to_s, @new_resource.mac_ip, nil)
        raise "Failed to reserve new vnet in network (#{@new_resource.network}): #{rc.message}" if OpenNebula.is_error?(rc) 
        @new_resource.updated_by_last_action(true)
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
