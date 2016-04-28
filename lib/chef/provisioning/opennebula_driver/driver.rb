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

require 'chef/provisioning/driver'
require 'chef/provisioning/machine/unix_machine'
require 'chef/provisioning/convergence_strategy/install_cached'
require 'chef/provisioning/convergence_strategy/install_sh'
require 'chef/provisioning/convergence_strategy/no_converge'
require 'chef/provisioning/transport/ssh'
require 'chef/provisioning/opennebula_driver/version'
require 'chef/provisioning/opennebula_driver/credentials'
require 'net/ssh/proxy/command'
require 'json'
require 'open3'

class Chef
  module DSL
    #
    # Module extension.
    #
    module Recipe
      def with_flow_url(url)
        run_context.chef_provisioning.with_flow_url(url)
      end
    end
  end
end

class Chef
  module Provisioning
    #
    # Class extension.
    #
    class ChefRunData
      attr_accessor :flow_url
      def with_flow_url(url)
        @flow_url = url
      end
    end
  end
end

class Chef
  module Provisioning
    module OpenNebulaDriver
      def self.match_driver_url(url, allow_nil_profile = false)
        scan = url.match(%r/opennebula:(https?:\/\/[^:\/]+ (?::[0-9]{2,5})? (?:\/[^:\s]+) ) :?([^:\s]+)?/x)
        fail "'driver_url' option has invalid format: #{url}" if scan.nil?
        endpoint = scan[1]
        profile = scan[2]
        fail "'driver_url' option is missing an endpoint: #{url}" if endpoint.nil?
        fail "'driver_url' option is missing a profile: #{url}" if profile.nil? && !allow_nil_profile
        [endpoint, profile]
      end

      def self.get_onelib(args)
        endpoint = args[:endpoint]
        credentials = args[:credentials]
        options = args[:options] || {}
        if args[:driver_url]
          fail "OpenNebula driver_url cannot be #{args[:driver_url].class}, it must be a String" unless args[:driver_url].is_a?(String)
          endpoint, profile = Chef::Provisioning::OpenNebulaDriver.match_driver_url(args[:driver_url])
          one_profile = Chef::Provisioning::OpenNebulaDriver::Credentials.new[profile]
          credentials = one_profile[:credentials]
          options = one_profile[:options] || {}
        end
        fail "OpenNebula credentials cannot be #{credentials.class}, it must be a String" unless credentials.is_a?(String)
        fail "OpenNebula endpoint cannot be #{endpoint.class}, it must be a String" unless endpoint.is_a?(String)
        fail "OpenNebula options cannot be #{options.class}, it must be a Hash" unless options.is_a?(Hash)
        server_version, _ = Open3.capture2e("ruby #{File.dirname(__FILE__)}/../driver_init/server_version.rb #{endpoint} #{credentials} #{options.to_json.inspect}")
        server_version.strip!
        fail server_version unless server_version =~ /^\d+\.\d+(?:\.\d+)?$/
        begin
          gem 'opennebula', "~> #{server_version}"
          require 'opennebula'
        rescue Gem::LoadError => e
          e_inspect = e.inspect
          if e_inspect.include?('already activated')
            Chef::Log.warn(e_inspect)
          else
            raise e
          end
        end
        require 'chef/provisioning/opennebula_driver/one_lib'
        gem_version = Gem.loaded_specs['opennebula'].version.to_s
        if gem_version == server_version
          Chef::Log.debug("You are using OpenNebula gem version #{gem_version} against OpenNebula server version #{server_version}")
        else
          Chef::Log.warn('OPENNEBULA GEM / SERVER VERSION MISMATCH')
          Chef::Log.warn("You are using OpenNebula gem version #{gem_version} against OpenNebula server version #{server_version}")
          Chef::Log.warn('Users may experience issues with this gem.')
        end
        OneLib.new(:credentials => credentials, :endpoint => endpoint, :options => options)
      end

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
        #   opennebula:<endpoint>:<profile>
        # where <profile> points to a one_auth file in ENV['HOME']/.one/<profile>
        #
        # driver_options:
        #   credentials: bbsl-auto:text_pass  credentials has precedence over secret_file
        #   endpoint: opennebula endpoint
        #   options: additional options for OpenNebula::Client
        #
        def initialize(driver_url, config)
          super
          @one = Chef::Provisioning::OpenNebulaDriver.get_onelib(:driver_url => driver_url)
          @driver_url_with_profile = driver_url
          @driver_url = @one.client.one_endpoint
        end

        def self.from_url(driver_url, config)
          Driver.new(driver_url, config)
        end

        # URL _must_ have an endpoint to prevent machine moving, which
        # is not possible today between different endpoints.
        def self.canonicalize_url(driver_url, config)
          [driver_url, config]
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
          instance = instance_for(machine_spec)
          return machine_spec unless instance.nil?

          unless machine_options[:bootstrap_options]
            fail "'bootstrap_options' must be specified"
          end
          check_unique_names(machine_options, machine_spec)
          action_handler.perform_action "created vm '#{machine_spec.name}'" do
            Chef::Log.debug(machine_options)
            tpl = @one.get_template(machine_spec.name,
                                    machine_options[:bootstrap_options])
            vm = @one.allocate_vm(tpl)
            populate_node_object(machine_spec, machine_options, vm)
            @one.chmod_resource(vm, machine_options[:bootstrap_options][:mode])

            # This option allows to manipulate how the machine shows up
            # in the OpenNebula UI and CLI tools.  We either set the VM
            # name to the short hostname of the machine, rename it
            # to the String passed to us, or leave it alone.
            if machine_options[:vm_name] == :short
              @one.rename_vm(vm, machine_spec.name.split('.').first)
            elsif machine_options[:vm_name].is_a?(String)
              @one.rename_vm(vm, machine_options[:vm_name])
              # else use machine_spec.name for name in OpenNebula
            end
          end
          Chef::Log.debug(machine_spec.reference)

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
          instance = instance_for(machine_spec)
          fail "Machine '#{machine_spec.name}' does not have an instance associated with it, or instance does not exist." if instance.nil?

          # TODO: Currently it does not start stopped VMs, it only waits for new VMs to be in RUNNING state
          machine = nil
          action_handler.perform_action "vm '#{machine_spec.name}' is ready" do
            deployed = @one.wait_for_vm(instance.id)
            machine_spec.reference['name'] = deployed.name
            machine_spec.reference['state'] = deployed.state_str
            if deployed.to_hash['VM']['TEMPLATE']['NIC']
              ip = [deployed.to_hash['VM']['TEMPLATE']['NIC']].flatten.first['IP']
            end
            fail "Could not get IP from VM '#{deployed.name}'" if ip.nil? || ip.to_s.empty?
            machine_spec.reference['ip'] = ip
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
          instance = instance_for(machine_spec)
          if !instance.nil?
            action_handler.perform_action "destroyed machine #{machine_spec.name} (#{machine_spec.reference['instance_id']})" do
              instance.delete
              1.upto(10) do
                instance.info
                break if instance.state_str == 'DONE'
                Chef::Log.debug("Waiting for VM '#{instance.id}' to be in 'DONE' state: '#{instance.state_str}'")
                sleep(2)
              end
              fail "Failed to destroy '#{instance.name}'.  Current state: #{instance.state_str}" if instance.state_str != 'DONE'
            end
          else
            if machine_spec.reference
              Chef::Log.info("vm #{machine_spec.name} (#{machine_spec.reference['instance_id']}) does not exist - (up to date)")
            else
              Chef::Log.info("vm #{machine_spec.name} does not exist - (up to date)")
            end
          end
          strategy = convergence_strategy_for(machine_spec, machine_options)
          strategy.cleanup_convergence(action_handler, machine_spec)
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
          instance = instance_for(machine_spec)
          if !instance.nil?
            action_handler.perform_action "powered off machine #{machine_spec.name} (#{machine_spec.reference['instance_id']})" do
              if machine_spec.reference[:is_shutdown] || (machine_options[:bootstrap_options] && machine_options[:bootstrap_options][:is_shutdown])
                hard = machine_spec.reference[:shutdown_hard] || machine_options[:bootstrap_options][:shutdown_hard] || false
                instance.shutdown(hard)
              else
                instance.stop
              end
            end
          else
            Chef::Log.info("vm #{machine_spec.name} (#{machine_spec.reference['instance_id']}) does not exist - (up to date)")
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
          if image_spec.reference
            # check if image already exists
            image = @one.get_resource(:image, :id => image_spec.reference['image_id'].to_i)
            action_handler.report_progress "image #{image_spec.name} (ID: #{image_spec.reference['image_id']}) already exists" unless image.nil?
          else
            action_handler.perform_action "create image #{image_spec.name} from machine ID #{machine_spec.reference['instance_id']} with options #{image_options.inspect}" do
              vm = @one.get_resource(:virtualmachine, :id => machine_spec.reference['instance_id'])
              fail "allocate_image: VM does not exist" if vm.nil?
              # set default disk ID
              disk_id = 1
              if image_options.disk_id
                disk_id = image_options.disk_id.is_a?(Integer) ? image_options.disk_id : @one.get_disk_id(vm, new_resource.disk_id)
              end
              new_img = @one.version_ge_4_14 ? vm.disk_saveas(disk_id, image_spec.name) : vm.disk_snapshot(disk_id, image_spec.name, "", true)

              fail "Failed to create snapshot '#{new_resource.name}': #{new_img.message}" if OpenNebula.is_error?(new_img)
              populate_img_object(image_spec, new_image)
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
        def ready_image(action_handler, image_spec, _image_options)
          img = @one.get_resource(:image, :id => image_spec.reference['image_id'].to_i)
          fail "Image #{image_spec.name} (#{image_spec.reference['image_id']}) does not exist" if img.nil?
          action_handler.perform_action "image #{image_spec.name} is ready" do
            deployed = @one.wait_for_img(img.name, img.id)
            image_spec.reference['state'] = deployed.state_str
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
        def destroy_image(action_handler, image_spec, _image_options)
          img = @one.get_resource(:image, :id => image_spec.location['image_id'].to_i)
          if img.nil?
            action_handler.report_progress "image #{image_spec.name} (#{image_spec.location['image_id']}) does not exist - (up to date)"
          else
            action_handler.perform_action "deleted image #{image_spec.name} (#{image_spec.location['image_id']})" do
              rc = img.delete
              fail "Failed to delete image '#{image_spec.name}' : #{rc.message}" if OpenNebula.is_error?(rc)
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
        def allocate_load_balancer(_action_handler, _lb_spec, _lb_options, _machine_specs)
          fail "'allocate_load_balancer' is not implemented"
        end

        # Make the load balancer ready
        # @param [ChefMetal::ActionHandler] action_handler The action handler
        # @param [ChefMetal::LoadBalancerSpec] lb_spec Frozen LB specification
        # @param [Hash] lb_options A hash of options to pass the LB
        def ready_load_balancer(_action_handler, _lb_spec, _lb_options, _machine_specs)
          fail "'ready_load_balancer' is not implemented"
        end

        # Destroy the load balancer
        # @param [ChefMetal::ActionHandler] action_handler The action handler
        # @param [ChefMetal::LoadBalancerSpec] lb_spec Frozen LB specification
        # @param [Hash] lb_options A hash of options to pass the LB
        def destroy_load_balancer(_action_handler, _lb_spec, _lb_options)
          fail "'destroy_load_balancer' is not implemented"
        end

        protected

        def one_credentials
          @one_credentials ||= begin
                                 credentials = Credentials.new(driver_options[:one_options] || {})
                                 if driver_options[:credentials]
                                   credentials.load_plain(driver_options[:credentials], driver_options[:one_options] || {})
                                 elsif driver_options[:secret_file]
                                   credentials.load_file(driver_options[:secret_file], driver_options[:one_options] || {})
                                 end
                                 credentials
                               end
        end

        def check_unique_names(machine_options, machine_spec)
          return unless machine_options[:bootstrap_options][:unique_names]
          hostname = if machine_options[:vm_name] == :short
                       machine_spec.name.split('.').first
                     elsif machine_options[:vm_name].is_a?(String)
                       machine_options[:vm_name]
                     else
                       machine_spec.name
                     end

          return if @one.get_resource(:virtualmachine, :name => hostname).nil?
          fail "VM with name '#{hostname}' already exists"
        end

        def populate_node_object(machine_spec, machine_options, vm)
          machine_spec.driver_url = @driver_url_with_profile
          machine_spec.reference = {
            'driver_version' => Chef::Provisioning::OpenNebulaDriver::VERSION,
            'allocated_at' => Time.now.utc.to_s,
            'image_id' => machine_options[:bootstrap_options][:image_id] || nil,
            'is_shutdown' => machine_options[:bootstrap_options][:is_shutdown] || false,
            'shutdown_hard' => machine_options[:bootstrap_options][:shutdown_hard] || false,
            'instance_id' => vm.id,
            'name' => vm.name,
            'state' => vm.state_str
          }
          # handle ssh_user and ssh_username for backward compatibility
          Chef::Log.warn("':ssh_user' will be deprecated in next version in favour of ':ssh_username'") if machine_options.key?(:ssh_user)
          machine_spec.reference['ssh_username'] = get_ssh_user(machine_spec, machine_options)
          %w(is_windows sudo transport_address_location ssh_gateway).each do |key|
            machine_spec.reference[key] = machine_options[key.to_sym] if machine_options[key.to_sym]
          end
        end

        def populate_img_object(image_spec, new_image)
          image_spec.driver_url = @driver_url_with_profile
          image_spec.reference = {
            'driver_version' => Chef::Provisioning::OpenNebulaDriver::VERSION,
            'image_id'       => new_image,
            'allocated_at'   => Time.now.to_i,
            'state'          => 'none'
          }
          image_spec.machine_options ||= {}
          image_spec.machine_options.merge!(:bootstrap_options => { :image_id => new_image })
        end

        def instance_for(machine_spec)
          instance = nil
          if machine_spec.reference
            current_endpoint, _ = Chef::Provisioning::OpenNebulaDriver.match_driver_url(machine_spec.driver_url, true)
            fail "Cannot move '#{machine_spec.name}' from #{current_endpoint} to #{driver_url}: machine moving is not supported.  Destroy and recreate." if current_endpoint != driver_url
            instance = @one.get_resource(:virtualmachine, :id => machine_spec.reference['instance_id'].to_i)
            machine_spec.driver_url = @driver_url_with_profile
          elsif machine_spec.location
            current_endpoint, _ = Chef::Provisioning::OpenNebulaDriver.match_driver_url(machine_spec.driver_url, true)
            fail "Cannot move '#{machine_spec.name}' from #{current_endpoint} to #{driver_url}: machine moving is not supported.  Destroy and recreate." if current_endpoint != driver_url
            instance = @one.get_resource(:virtualmachine, :id => machine_spec.location['server_id'].to_i)
            machine_spec.driver_url = @driver_url_with_profile
            unless instance.nil?
              # Convert from previous driver
              machine_spec.reference = {
                  'driver_version' => machine_spec.location['driver_version'],
                  'allocated_at' => machine_spec.location['allocated_at'],
                  'image_id' => machine_spec.location['image_id'],
                  'instance_id' => machine_spec.location['server_id'],
                  'name' => machine_spec.location['name'],
                  'state' => machine_spec.location['state']
              }
            end
          end
          instance
        end

        def machine_for(machine_spec, machine_options)
          instance = instance_for(machine_spec)
          fail "#{machine_spec.name} (#{machine_spec.reference['instance_id']}) does not exist!" if instance.nil?
          # TODO: Support Windoze VMs (see chef-provisioning-vagrant)
          Chef::Provisioning::Machine::UnixMachine.new(
            machine_spec,
            transport_for(machine_spec, machine_options, instance),
            convergence_strategy_for(machine_spec, machine_options)
          )
        end

        def get_ssh_user(machine_spec, machine_options)
          # handle ssh_user and ssh_username for backward compatibility
          Chef::Log.warn("':ssh_user' will be deprecated in next version in favour of ':ssh_username'") if machine_options.key?(:ssh_user)
          machine_spec.reference['ssh_username'] || machine_options[:ssh_username] || machine_options[:ssh_user] || 'local'
        end

        def transport_for(machine_spec, machine_options, _instance)
          ssh_options = {
            :keys_only => false,
            :forward_agent => true,
            :use_agent => true,
            :user_known_hosts_file => '/dev/null',
            :timeout => 10
          }.merge(machine_options[:ssh_options] || {})
          ssh_options[:proxy] = Net::SSH::Proxy::Command.new(ssh_options[:proxy]) if ssh_options.key?(:proxy)

          connection_timeout = machine_options[:connection_timeout] || 300
          username = get_ssh_user(machine_spec, machine_options)

          options = {}
          if machine_spec.reference[:sudo] || (!machine_spec.reference.key?(:sudo) && username != 'root')
            options[:prefix] = 'sudo '
          end
          options[:ssh_pty_enable] = machine_options[:ssh_pty_enable] || true
          # User provided ssh_gateway takes precedence over machine_spec value
          options[:ssh_gateway] = machine_options[:ssh_gateway] || machine_spec.reference['ssh_gateway']

          transport = Chef::Provisioning::Transport::SSH.new(machine_spec.reference['ip'], username, ssh_options, options, config)

          # wait up to 5 min to establish SSH connection
          connect_sleep = 3
          start = Time.now
          loop do
            break if transport.available?
            fail "Failed to establish SSH connection to '#{machine_spec.name}'" if Time.now > start + connection_timeout.to_i
            Chef::Log.info("Waiting for SSH server ...")
            sleep connect_sleep
          end
          transport
        end

        def convergence_strategy_for(machine_spec, machine_options)
          # TODO: Support Windoze VMs (see chef-provisioning-vagrant)
          convergence_options = Cheffish::MergedConfig.new(machine_options ? machine_options[:convergence_options] || {} : {})

          if !machine_spec.reference
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
