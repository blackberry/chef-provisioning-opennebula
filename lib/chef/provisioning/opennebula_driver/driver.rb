require 'chef/provisioning/driver'
require 'chef/provisioning/machine/unix_machine'
require 'chef/provisioning/convergence_strategy/install_cached'
require 'chef/provisioning/convergence_strategy/install_sh'
require 'chef/provisioning/convergence_strategy/no_converge'
require 'chef/provisioning/transport/ssh'
require 'chef/provisioning/opennebula_driver/version'
require 'chef/provisioning/opennebula_driver/one_lib'

class Chef
  module Provisioning
    module OpenNebulaDriver

      #
      # A Driver instance represents a place where machines can be created
      # and found, and contains methods to create, delete, start, stop, and
      # find them.
      #
      # For AWS, a Driver instance corresponds to a single account.
      # For Vagrant, it is a directory where VM files are found.
      #
      # = How to Make a Driver
      #
      # To implement a Driver, you must implement the following methods:
      #
      # * initialize(driver_url) - create a new driver with the given URL
      # * driver_url - a URL representing everything unique about your
      #                driver. (NOT credentials)
      # * allocate_machine - ask the driver to allocate a machine to you.
      # * ready_machine - get the machine "ready" - wait for it to be booted
      #                   and accessible (for example, accessible via SSH
      #                   transport).
      # * stop_machine - stop the machine.
      # * destroy_machine - delete the machine.
      # * connect_to_machine - connect to the given machine.
      #
      # Optionally, you can also implement:
      # * allocate_machines - allocate an entire group of machines.
      # * ready_machines - get a group of machines warm and booted.
      # * stop_machines - stop a group of machines.
      # * destroy_machines - delete a group of machines.
      #
      # Additionally, you must create a file named
      # `chef/provisioning/driver_init/<scheme>.rb`,
      # where <scheme> is the name of the scheme you chose for your driver_url.
      # This file, when required, must call
      # Chef::Provisioning.add_registered_driver(<scheme>, <class>).
      # The given <class>.from_url(url, config) will be called with a
      # driver_url and configuration.
      #
      # All of these methods must be idempotent - if the work is already done,
      # they just don't do anything.
      #
      class Driver < Chef::Provisioning::Driver
        attr_reader :one

        #
        # OpenNebula by default reads the following information:
        #
        #  username:password from ENV['ONE_AUTH'] or ENV['HOME']/.one/one_auth
        #  endpoint from ENV['ONE_XMLRPC']
        #
        # driver_url format:
        #   opennebula:<endpoint>
        #
        # driver_options:
        #   credentials: bbsl-auto:text_pass  credentials has precedence over secret_file
        #   secret_file: path_to_one_auth_file
        #
        def initialize(driver_url, config)
          super
          Chef::Log.debug("DRIVER_URL: #{driver_url}")
          Chef::Log.debug("CONFIG: #{config}")
          _, endpoint = driver_url.split(':', 2)
          user_pass   = driver_options[:credentials]
          secret_file = driver_options[:secret_file]

          if !user_pass.nil? and !user_pass.empty?
            credentials = user_pass
          elsif !secret_file.nil? and !secret_file.empty?
            credentials = File.read(secret_file).strip
          end
          client_options = driver_options[:one_options] || {}
          @one = OneLib.new(credentials, endpoint, client_options)
        end

        def self.from_url(driver_url, config)
          Driver.new(driver_url, config)
        end

        # URL _must_ have an endpoint to prevent machine moving, which
        # is not possible today between different endpoints.
        def self.canonicalize_url(driver_url, config)
          _, endpoint = driver_url.split(':', 2)
          [ "opennebula:#{endpoint}", config ]
        end

        # Allocate a machine from the underlying service.  This method
        # does not need to wait for the machine to boot or have an IP, but
        # it must store enough information in machine_spec.location to find
        # the machine later in ready_machine.
        #
        # If a machine is powered off or otherwise unusable, this method may
        # start it, but does not need to wait until it is started.  The
        # idea is to get the gears moving, but the job doesn't need to be
        # done :)
        #
        # @param [Chef::Provisioning::ActionHandler] action_handler
        #   The action_handler object that is calling this method
        # @param [Chef::Provisioning::MachineSpec] machine_spec
        #   A machine specification representing this machine.
        # @param [Hash] machine_options
        #   A set of options representing the desired options when
        #   constructing the machine
        #
        # @return [Chef::Provisioning::MachineSpec]
        #   Modifies the passed-in machine_spec.  Anything in here will be
        #   saved back after allocate_machine completes.
        #
        def allocate_machine(action_handler, machine_spec, machine_options)
          raise "Machine 'name' must be a FQDN" if machine_options.bootstrap_options[:enforce_chef_fqdn] and machine_spec.name.scan(/([a-z0-9-]+\.)/i).length == 0
          if machine_spec.location
            vm = @one.get_resource('vm', { :id => machine_spec.location['server_id'].to_i })
            # check if machine already exists in OpenNebula
            if vm.nil?
              action_handler.perform_action "VM #{machine_spec.name} does not exist.  Creating..." do
                machine_spec.location = nil
              end
            else
              # update VM info
              machine_spec.location['server_id'] = vm.id
              machine_spec.location['name'] = vm.name
              machine_spec.location['state'] = vm.state_str
              machine_spec.location['lcm_state'] = vm.lcm_state_str
              # reboot VM if in 'STOPPED' or 'POWEROFF' state
              if vm.state_str == 'STOPPED' or vm.state_str == 'POWEROFF'
                action_handler.perform_action "VM #{machine_spec.name} exists.  Rebooting..." do
                  vm.reboot
                end
              end
            end
          end
          # create if not exists
          if !machine_spec.location
            vm = nil
            action_handler.perform_action "created VM #{machine_spec.name}" do
              Chef::Log.debug(machine_options)
              tpl = @one.get_template(machine_spec.name, machine_options.bootstrap_options)
              vm = @one.allocate_vm(tpl)
            end
            machine_spec.location = {
              'driver_url' => driver_url,
              'driver_version' => Chef::Provisioning::OpenNebulaDriver::VERSION,
              'server_id' => vm.id,
              'name' => vm.name,
              'state' => vm.state_str,
              'lcm_state' => vm.lcm_state_str,
              'allocated_at' => Time.now.utc.to_s
            }
            Chef::Log.debug(machine_spec.location)
          end
          machine_spec
        end

        # Ready a machine, to the point where it is running and accessible
        # via a transport. This will NOT allocate a machine, but may kick
        # it if it is down. This method waits for the machine to be usable,
        # returning a Machine object pointing at the machine, allowing useful
        # actions like setup, converge, execute, file and directory.
        #
        #
        # @param [Chef::Provisioning::ActionHandler] action_handler
        #     The action_handler object that is calling this method
        # @param [Chef::Provisioning::MachineSpec] machine_spec
        #     A machine specification representing this machine.
        # @param [Hash] machine_options
        #     A set of options representing the desired state of the machine
        #
        # @return [Machine] A machine object pointing at the machine, allowing
        #   useful actions like setup, converge, execute, file and directory.
        #
        def ready_machine(action_handler, machine_spec, machine_options)
          # TODO: Currently it does not start stopped VMs, it only waits for new VMs to be in RUNNING state
          state = 'LCM_INIT'
          machine = nil
          deployed = nil
          id = machine_spec.location['server_id']

          action_handler.perform_action "VM '#{machine_spec.name}' is ready" do
            deployed = @one.wait_for_vm(id)
            machine_spec.location['name'] = deployed.name
            machine_spec.location['state'] = deployed.state_str
            machine_spec.location['lcm_state'] = deployed.lcm_state_str
            nic_hash = deployed.to_hash
            ip = nil
            if nic_hash['VM']['TEMPLATE']['NIC'].is_a?(Array)
              ip = nic_hash['VM']['TEMPLATE']['NIC'][0]['IP']
            else
              ip = deployed['TEMPLATE/NIC/IP']
            end
            raise "Could not get IP from VM '#{deployed.name}'" if ip.nil?
            machine_spec.location['ip'] = ip
            machine = machine_for(machine_spec, machine_options)
          end
          machine
        end

        # Connect to a machine without allocating or readying it.  This method will
        # NOT make any changes to anything, or attempt to wait.
        #
        # @param [Chef::Provisioning::MachineSpec] machine_spec
        #     MachineSpec representing this machine.
        # @param [Hash] machine_options
        # @return [Machine] A machine object pointing at the machine, allowing
        #   useful actions like setup, converge, execute, file and directory.
        #
        def connect_to_machine(machine_spec, machine_options)
          machine_for(machine_spec, machine_options)
        end


        # Delete the given machine --  destroy the machine,
        # returning things to the state before allocate_machine was called.
        #
        # @param [Chef::Provisioning::ActionHandler] action_handler
        #     The action_handler object that is calling this method
        # @param [Chef::Provisioning::MachineSpec] machine_spec
        #     A machine specification representing this machine.
        # @param [Hash] machine_options
        #     A set of options representing the desired state of the machine
        def destroy_machine(action_handler, machine_spec, machine_options)
          if machine_spec.location
            # machine_spec.name == machine_spec.location['name'] ???
            vm = @one.get_resource('vm', { :id => machine_spec.location['server_id'].to_i })
            if !vm.nil?
              action_handler.perform_action "destroyed machine #{machine_spec.name} (#{machine_spec.location['server_id']})" do
                vm.delete
              end
            else
              Chef::Log.info("VM #{machine_spec.name} (#{machine_spec.location['server_id']}) does not exist.")
            end
            strategy = convergence_strategy_for(machine_spec, machine_options)
            strategy.cleanup_convergence(action_handler, machine_spec)
          end
        end

        # Stop the given machine.
        #
        # @param [Chef::Provisioning::ActionHandler] action_handler
        #     The action_handler object that is calling this method
        # @param [Chef::Provisioning::MachineSpec] machine_spec
        #     A machine specification representing this machine.
        # @param [Hash] machine_options
        #     A set of options representing the desired state of the machine
        def stop_machine(action_handler, machine_spec, machine_options)
          if machine_spec.location
            action_handler.perform_action "powered off machine #{machine_spec.name} (#{machine_spec.location['server_id']})" do
              vm = @one.get_resource('vm', { :id => machine_spec.location['server_id'].to_i })
              if !vm.nil?
                vm.stop
              else
                Chef::Log.info("VM #{machine_spec.name} (#{machine_spec.location['server_id']}) does not exist.")
              end
            end
          end
        end

        # Allocate an image. Returns quickly with an ID that tracks the image.
        #
        # @param [Chef::Provisioning::ActionHandler] action_handler
        #     The action_handler object that is calling this method
        # @param [Chef::Provisioning::ImageSpec] image_spec
        #     A machine specification representing this machine.
        # @param [Hash] image_options
        #     A set of options representing the desired state of the machine
        def allocate_image(action_handler, image_spec, image_options, machine_spec)
          if img_spec.location
            # check if image already exists
            vm_img = @one.get_resource('img', { :id => img_spec.location['image_id'].to_i })
            if vm_img.nil?
              action_handler.perform_action "image '#{image_spec.name}' does not exist. Creating..." do
                image_spec.location = nil
              end
            else
              image_spec.location['image_id'] = vm_img.id
              image_spec.location['name'] = vm_img.name
              image_spec.location['state'] = vm_img.state_str
              image_spec.location['type'] = vm_img.type_str
            end
          end
          if !img_spec.location
            action_handler.perform_action "created image #{image_spec.name} from machine ID #{machine_spec.location['server_id']} with options #{image_options.inspect}" do
              vm = @one.get_resource('vm', { :id => machine_spec.location['server_id'] })
              raise "allocate_image: VM does not exist" if vm.nil?
              # set default disk ID
              disk_id = 1
              if !image_options.disk_id.nil?
                disk_id = image_options.disk_id.is_a?(Integer) ? image_options.disk_id : @one.get_disk_id(vm, new_resource.disk_id)
              end

              new_img = vm.disk_snapshot(disk_id, image_spec.name, "", true)
              raise "Failed to create snapshot '#{new_resource.name}': #{new_img.message}" if OpenNebula.is_error?(new_img)
              image_spec.location = {
                'driver_url' => driver_url,
                'driver_version' => Chef::Provisioning::OpenNebulaDriver::VERSION,
                'image_id' => new_image,
                'allocated_at' => Time.now.to_i
              }
              image_spec.machine_options ||= {}
              image_spec.machine_options.merge!({
                :bootstrap_options => {
                   :image_id => new_image
                }
              })
            end
          end
        end

        # Ready an image, waiting till the point where it is ready to be used.
        #
        # @param [Chef::Provisioning::ActionHandler] action_handler
        #     The action_handler object that is calling this method
        # @param [Chef::Provisioning::ImageSpec] image_spec
        #     A machine specification representing this machine.
        # @param [Hash] image_options
        #     A set of options representing the desired state of the machine
        def ready_image(action_handler, image_spec, image_options)
          img = @one.get_resource('img', { :id => image_spec.location['image_id'].to_i })
          raise "Image #{image_spec.name} (#{image_spec['image_id']}) does not exist" if img.nil?
          action_handler.perform_action "image #{image_spec.name} is ready" do
            deployed = @one.wait_for_img(img.name, img.id)
            image_spec.location['state'] = deployed.state_str
          end
          img
        end

        # Destroy an image using this service.
        #
        # @param [Chef::Provisioning::ActionHandler] action_handler
        #     The action_handler object that is calling this method
        # @param [Chef::Provisioning::ImageSpec] image_spec
        #     A machine specification representing this machine.
        # @param [Hash] image_options
        #     A set of options representing the desired state of the machine
        def destroy_image(action_handler, image_spec, image_options)
          img = @one.get_resource('img', { :id => image_spec.location['image_id'].to_i })
          if img.nil?
            action_handler.report_progress "image #{image_spec.name} (#{image_spec.location['image_id']}) does not exist - nothing to do"
          else
            action_handler.perform_action "deleted image #{image_spec.name} (#{image_spec.location['image_id']})" do
              rc = img.delete
              raise "Failed to delete image '#{image_spec.name}' : #{rc.message}" if OpenNebula.is_error?(rc)
              # TODO: Check for VM in use and delete them too
              #       If 'delete_snapshots' is true then delete those VMs
            end
          end
        end

        #
        # Optional interface methods
        #

        #
        # Allocate a set of machines.  This should have the same effect as
        # running allocate_machine on all machine_specs.
        #
        # Drivers do not need to implement this; the default implementation
        # calls acquire_machine in parallel.
        #
        # == Parallelizing
        #
        # The parallelizer must implement #parallelize
        # @example Example parallelizer
        #   parallelizer.parallelize(specs_and_options) do |machine_spec|
        #     allocate_machine(action_handler, machine_spec)
        #   end.to_a
        #   # The to_a at the end causes you to wait until the
        #   parallelization is done
        #
        # This object is shared among other chef-provisioning actions, ensuring
        # that you do not go over parallelization limits set by the user.  Use
        # of the parallelizer to parallelizer machines is not required.
        #
        # == Passing a block
        #
        # If you pass a block to this function, each machine will be yielded
        # to you as it completes, and then the function will return when
        # all machines are yielded.
        #
        # @example Passing a block
        #   allocate_machines(
        #     action_handler,
        #     specs_and_options,
        #     parallelizer) do |machine_spec|
        #     ...
        #   end
        #
        # @param [Chef::Provisioning::ActionHandler] action_handler
        #        The action_handler object that is calling this method; this
        #        is generally a driver, but could be anything that can support
        #        the interface (i.e., in the case of the test kitchen
        #        provisioning driver for acquiring and destroying VMs).
        # @param [Hash] specs_and_options
        #        A hash of machine_spec -> machine_options representing the
        #        machines to allocate.
        # @param [Parallelizer] parallelizer an object with a
        #        parallelize() method that works like this:
        # @return [Array<Machine>] An array of machine objects created
        def allocate_machines(action_handler, specs_and_options, parallelizer)
          parallelizer.parallelize(specs_and_options) do |machine_spec, machine_options|
            allocate_machine(add_prefix(machine_spec, action_handler), machine_spec, machine_options)
            yield machine_spec if block_given?
            machine_spec
          end.to_a
        end

        # Ready machines in batch, in parallel if possible.
        def ready_machines(action_handler, specs_and_options, parallelizer)
          parallelizer.parallelize(specs_and_options) do |machine_spec, machine_options|
            machine = ready_machine(add_prefix(machine_spec, action_handler), machine_spec, machine_options)
            yield machine if block_given?
            machine
          end.to_a
        end

        # Stop machines in batch, in parallel if possible.
        def stop_machines(action_handler, specs_and_options, parallelizer)
          parallelizer.parallelize(specs_and_options) do |machine_spec, machine_options|
            stop_machine(add_prefix(machine_spec, action_handler), machine_spec, machine_options)
            yield machine_spec if block_given?
          end.to_a
        end

        # Delete machines in batch, in parallel if possible.
        def destroy_machines(action_handler, specs_and_options, parallelizer)
          parallelizer.parallelize(specs_and_options) do |machine_spec, machine_options|
            destroy_machine(add_prefix(machine_spec, action_handler), machine_spec, machine_options)
            yield machine_spec if block_given?
          end.to_a
        end

        # Allocate a load balancer
        # @param [ChefMetal::ActionHandler] action_handler The action handler
        # @param [ChefMetal::LoadBalancerSpec] lb_spec Frozen LB specification
        # @param [Hash] lb_options A hash of options to pass the LB
        # @param [Array[ChefMetal::MachineSpec]] machine_specs
        #        An array of machine specs the load balancer should have
        def allocate_load_balancer(action_handler, lb_spec, lb_options, machine_specs)
        end

        # Make the load balancer ready
        # @param [ChefMetal::ActionHandler] action_handler The action handler
        # @param [ChefMetal::LoadBalancerSpec] lb_spec Frozen LB specification
        # @param [Hash] lb_options A hash of options to pass the LB
        def ready_load_balancer(action_handler, lb_spec, lb_options, machine_specs)
        end

        # Destroy the load balancer
        # @param [ChefMetal::ActionHandler] action_handler The action handler
        # @param [ChefMetal::LoadBalancerSpec] lb_spec Frozen LB specification
        # @param [Hash] lb_options A hash of options to pass the LB
        def destroy_load_balancer(action_handler, lb_spec, lb_options)
        end

        protected

        def machine_for(machine_spec, machine_options)
          if @one.get_resource('vm', { :id => machine_spec.location['server_id'].to_i }).nil?
            raise "#{machine_spec.name} (#{machine_spec.location['server_id']}) does not exist!"
          end
          # TODO: Support Windoze VMs (see chef-provisioning-vagrant)
          Chef::Provisioning::Machine::UnixMachine.new(machine_spec, transport_for(machine_spec, machine_options), convergence_strategy_for(machine_spec, machine_options))
        end

        def transport_for(machine_spec, machine_options)
          # TODO: Support Windoze VMs (see chef-provisioning-vagrant)
          transport = Chef::Provisioning::Transport::SSH.new(
            machine_spec.location['ip'],
            machine_options[:ssh_user],
            machine_options[:ssh_options] || {},
            machine_options[:ssh_execute_options] || { :prefix => 'sudo ' },
            machine_options[:ssh_config] || config)

          # wait up to 5 min to establish SSH connection
          100.times {
            break if transport.available?
            sleep 3
            Chef::Log.debug("Waiting for SSH server ...")
          }
          raise "Failed to establish SSH connection to #{machine_spec.name}" if !transport.available?
          transport
        end

        def convergence_strategy_for(machine_spec, machine_options)
          # TODO: Support Windoze VMs (see chef-provisioning-vagrant)
          convergence_options = Cheffish::MergedConfig.new(machine_options[:convergence_options] || {})

          if !machine_spec.location
            Chef::Provisioning::ConvergenceStrategy::NoConverge.new(convergence_options, config)
          elsif machine_options[:cached_installer] == true
            Chef::Provisioning::ConvergenceStrategy::InstallCached.new(convergence_options, config)
          else
            Chef::Provisioning::ConvergenceStrategy::InstallSh.new(convergence_options, config)
          end
        end

        def add_prefix(machine_spec, action_handler)
          AddPrefixActionHandler.new(action_handler, "[#{machine_spec.name}] ")
        end

        def get_private_key(name)
          Cheffish.get_private_key(name, config)
        end
      end
    end
  end
end
