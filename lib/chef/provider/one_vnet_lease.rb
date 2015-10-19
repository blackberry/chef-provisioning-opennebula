
class Chef::Provider::OneVnetLease < Chef::Provider::LWRPBase
  use_inline_resources

  attr :current_vnet
  
  def action_handler
    @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
  end

  def exists?
    new_driver = get_driver
    filter = {
      :id => @new_resource.vnet.is_a?(Integer) ? @new_resource.vnet : nil, 
      :name => @new_resource.vnet.is_a?(String) ? @new_resource.vnet : nil
    }
    @current_vnet = new_driver.one.get_resource('vnet', filter)
    raise "vnet '#{@new_resource.vnet}' does not exist" if @current_vnet.nil?
    @current_vnet.info!
    hash = @current_vnet.to_hash

    lookup = @new_resource.name.include?(':') ? 'MAC' : 'IP'
    ar_pool = [hash['VNET']['AR_POOL']].flatten
    exists, vm  = false, -2

    if @new_resource.ar_id and @new_resource.ar_id > -1
      ar_pool.each { |a|
        if a['AR']['AR_ID'] == @new_resource.ar_id.to_s
          ar_pool = [a]
          break
        end
      }
      raise "ar_id not found '#{@new_resource.ar_id}'" if ar_pool[0]['AR']['AR_ID'] != @new_resource.ar_id.to_s
    end
    ar_pool.each { |a|
      if a['AR']['LEASES']['LEASE']
        [a['AR']['LEASES']['LEASE']].flatten.each { |l|
          if l[lookup] and l[lookup] == @new_resource.name 
            exists = true
            vm = l['VM'].to_i
            break
          end
        }
      end
    }
    raise "'#{name}' is already allocated to a VM (ID: #{vm.to_s})" if exists and vm > -1
    (exists and vm  == -1)
  end

  action :hold do
    if exists?
      action_handler.report_progress("#{@new_resource.name} is already on hold and not used")
    else
      action_handler.perform_action "hold '#{@new_resource.name}'" do
        rc = @current_vnet.hold(@new_resource.name, @new_resource.ar_id || -1)
        raise "Failed to put a hold on '#{@new_resource.name}': #{rc.message}" if OpenNebula.is_error?(rc) 
        @new_resource.updated_by_last_action(true)
      end
    end
  end

  action :release do
    if exists?
      action_handler.perform_action "released '#{@new_resource.name}'" do
        rc = @current_vnet.release(@new_resource.name, @new_resource.ar_id || -1)
        raise "Failed to release '#{@new_resource.name}': #{rc.message}" if OpenNebula.is_error?(rc) 
        @new_resource.updated_by_last_action(true)
      end
    else
      action_handler.report_progress("#{@new_resource.name} is not present - nothing do to")
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
