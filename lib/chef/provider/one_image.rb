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

#
# Implementation of Provider class.
#
class Chef
  #
  # Implementation of Provider class.
  #
  class Provider
    #
    # Implementation of Provider class.
    #
    class OneImage < Chef::Provider::LWRPBase
      use_inline_resources

      provides :one_image

      attr_reader :image

      def whyrun_supported?
        true
      end

      def load_current_resource
      end

      def action_handler
        @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
      end

      def exists?
        new_driver = driver
        @image = new_driver.one.get_resource(:image, :name => @new_resource.name)
        !@image.nil?
      end

      action :allocate do
        if exists?
          # Image already exists, check whether we need/can update it
          # OpenNebula Image example:
          # ID             : 14202
          # NAME           : ey-test
          # USER           : Mandolin
          # GROUP          : users
          # DATASTORE      : orn-svc01-ds
          # TYPE           : DATABLOCK
          # REGISTER TIME  : 10/19 18:16:02
          # PERSISTENT     : No
          # SOURCE         : /var/lib/one/datastores/103/743dff63f337a0192b13f2963f92d741
          # FSTYPE         : raw
          # SIZE           : 1000M
          # STATE          : rdy
          # RUNNING_VMS    : 0
          #
          # PERMISSIONS
          # OWNER          : um-
          # GROUP          : ---
          # OTHER          : ---
          #
          # IMAGE TEMPLATE
          # DESCRIPTION="what a heck!"
          # DEV_PREFIX="vd"
          # DRIVER="qcow2"
          # FSTYPE="ext4"
          # SIZE="100"
          #
          # We can update many parameters and whatever we update goes into section below 'IMAGE TEMPLATE'.
          # IMPORTANT: if the parameter we are updating exists above 'IMAGE TEMPLATE' then our modification has no effect.
          # In other words a value for a parameter defined above wins over parameter defined below 'IMAGE TEMPLATE'.

          on_image = @image.to_hash['IMAGE']

          # We can update only following attributes. This is a map of one_image attributes to OpenNebula image attributes
          attrs_map = { 'name' => 'NAME', 'size' => 'SIZE', 'datastore_id' => 'DATASTORE_ID', 'type' => 'TYPE', 'description' => 'DESCRIPTION', 'fs_type' => 'FSTYPE',
                        'img_driver' => 'DRIVER', 'prefix' => 'DEV_PREFIX', 'persistent' => 'PERSISTENT', 'mode' => 'PERMISSIONS', 'disk_type' => 'DISK_TYPE' }

          # Find out what attribute needs to be updated
          attrs_to_update = {}
          new_resource_hash = @new_resource.to_hash # hash keys are symbols
          new_resource_hash.each do |k, v|
            next if v.nil? || !attrs_map.key?(k.to_s)
            v = v.to_s # everything is String in what we get in OpenNebula Image info
            on_attr = attrs_map[k.to_s]

            # For some one_image attributes provided in new_resource we need to find respective values in ON Image
            case k
            when :type
              image_types = %w(OS CDROM DATABLOCK KERNEL RAMDISK CONTEXT)
              on_image['TYPE'] = image_types[on_image['TYPE'].to_i] # convert Image Type Id into String
            when :persistent
              on_image['PERSISTENT'] = (on_image['PERSISTENT'] == '1' ? 'true' : 'false')
            when :mode
              perm = on_image['PERMISSIONS']
              perm_octet_u = perm['OWNER_U'].to_i * 4 + perm['OWNER_M'].to_i * 2 + perm['OWNER_A'].to_i
              perm_octet_g = perm['GROUP_U'].to_i * 4 + perm['GROUP_M'].to_i * 2 + perm['GROUP_A'].to_i
              perm_octet_o = perm['OTHER_U'].to_i * 4 + perm['OTHER_M'].to_i * 2 + perm['OTHER_A'].to_i
              on_image['PERMISSIONS'] = "#{perm_octet_u}#{perm_octet_g}#{perm_octet_o}"
            when :disk_type
              disk_types = %w(BLOCK CDROM FILE)
              on_image['DISK_TYPE'] = disk_types[on_image['DISK_TYPE'].to_i] # convert Disk Type into String
            end
            next if on_image.key?(on_attr) && (v == on_image[on_attr])
            next if on_image['TEMPLATE'].key?(on_attr) && (new_resource_hash[k] == on_image['TEMPLATE'][on_attr])
            fail "Cannot update '#{on_attr}' as it is defined above 'IMAGE TEMPLATE' section." if on_image.key?(on_attr) && !on_image[on_attr].empty? && on_attr != 'PERMISSIONS'
            attrs_to_update[on_attr] = v
          end

          unless attrs_to_update.empty?
            # Prepare template to update
            img_template = ''
            attrs_to_update.each do |k, v|
              next if k == 'PERMISSIONS' # needs special treatment
              img_template << case k
                              when 'SIZE', 'PERSISTENT'
                                "#{k} = #{v}\n"
                              when 'TYPE', 'DESCRIPTION', 'FSTYPE', 'DRIVER', 'DEV_PREFIX', 'DISK_TYPE'
                                "#{k} = \"#{v}\"\n"
                              end
            end
            # Perform actual update
            description = "updated image '#{new_resource.name}'\n" + attrs_to_update.to_s
            action_handler.perform_action description do
              unless img_template == '' # can happen when we update only PERMISSIONS
                rc = @image.update(img_template, true)
                fail "failed to update image '#{new_resource.name}': #{rc.message}" if OpenNebula.is_error?(rc)
              end
              if attrs_to_update.key?('PERMISSIONS')
                rc = @image.chmod_octet(attrs_to_update['PERMISSIONS'])
                fail "failed to update image '#{new_resource.name}': #{rc.message}" if OpenNebula.is_error?(rc)
              end
            end
          end
        else
          fail "'size' must be specified" unless new_resource.size
          fail "'datastore_id' must be specified" unless new_resource.datastore_id

          action_handler.perform_action "allocated image '#{new_resource.name}'" do
            @image = new_driver.one.allocate_img(
              :name => new_resource.name,
              :size => new_resource.size,
              :datastore_id => new_resource.datastore_id,
              :type => new_resource.type || 'OS',
              :fs_type => new_resource.fs_type || 'ext2',
              :driver => new_resource.img_driver || 'qcow2',
              :prefix => new_resource.prefix || 'vd',
              :persistent => new_resource.persistent || false)
            new_driver.one.chmod_resource(@image, new_resource.mode)
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
        else
          fail "Image #{new_resource.name} is in unexpected state '#{@image.state_str}'"
        end
      end

      action :destroy do
        if exists?
          action_handler.perform_action "deleted image '#{new_resource.name}'" do
            rc = @image.delete
            fail "Failed to delete image '#{new_resource.name}' : #{rc.message}" if OpenNebula.is_error?(rc)
            until new_driver.one.get_resource(:image, :name => new_resource.name).nil?
              Chef::Log.debug("Waiting for delete image to finish...")
              sleep 1
            end
            @new_resource.updated_by_last_action(true)
          end
        else
          action_handler.report_progress "image '#{new_resource.name}' does not exist - (up to date)"
        end
      end

      action :attach do
        fail "Missing attribute 'machine_id'" unless new_resource.machine_id
        fail "Failed to attach disk - image '#{new_resource.name}' does not exist" unless exists?

        vm = new_driver.one.get_resource(:virtualmachine, new_resource.machine_id.is_a?(Integer) ? :id : :name => new_resource.machine_id)
        fail "Failed to attach disk - VM '#{new_resource.machine_id}' does not exist" if vm.nil?
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
            action_handler.report_progress "disk is already attached - (up to date)" unless disk_id.nil?
          elsif disk_id.nil?
            action_handler.report_progress "disk not attached, attaching..."
            rc = vm.disk_attach(disk_tpl)
            new_driver.one.wait_for_vm(vm.id)
            fail "Failed to attach disk to VM '#{vm.name}': #{rc.message}" if OpenNebula.is_error?(rc)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :snapshot do
        fail "Missing attribute 'machine_id'" unless new_resource.machine_id
        fail "snapshot '#{new_resource.name}' already exists" if exists?
        vm = new_driver.one.get_resource(:virtualmachine, new_resource.machine_id.is_a?(Integer) ? :id : :name => new_resource.machine_id)
        fail "Failed to create snapshot - VM '#{new_resource.machine_id}' does not exist" if vm.nil?
        action_handler.perform_action "created snapshot from '#{new_resource.machine_id}'" do
          disk_id = new_resource.disk_id.is_a?(Integer) ? new_resource.disk_id : new_driver.one.get_disk_id(vm, new_resource.disk_id)
          fail "No disk '#{new_resource.disk_id}' found on '#{vm.name}'" if disk_id.nil?
          @image = new_driver.one.version_ge_4_14 ? vm.disk_saveas(disk_id, new_resource.name) : vm.disk_snapshot(disk_id, new_resource.name, "", true)
          fail "Failed to create snapshot '#{new_resource.name}': #{@image.message}" if OpenNebula.is_error?(@image)

          @image = new_driver.one.wait_for_img(new_resource.name, @image)
          new_driver.one.chmod_resource(image, new_resource.mode)
          if new_resource.persistent
            action_handler.report_progress "make image '#{new_resource.name}' persistent"
            @image.persistent
          end
          @new_resource.updated_by_last_action(true)
        end
      end

      action :upload do
        fail "'datastore_id' is required" unless new_resource.datastore_id
        fail "'image_file' or 'download_url' attribute is required" unless new_resource.image_file || new_resource.download_url

        file_url = nil
        if new_resource.image_file
          fail "image_file #{new_resource.image_file} does not exist" unless ::File.exist? new_resource.image_file
          file_url = "http://#{node['ipaddress']}:#{@new_resource.http_port}/#{::File.basename(@new_resource.image_file)}"
        else
          file_url = new_resource.download_url
        end
        image_config = {
          :name => @new_resource.name,
          :datastore_id => @new_resource.datastore_id.to_s,
          :path => file_url,
          :driver => @new_resource.img_driver || 'qcow2',
          :description => @new_resource.description || "#{@new_resource.name} image",
          :type => @new_resource.type,
          :mode => @new_resource.mode,
          :prefix => @new_resource.prefix,
          :persistent => @new_resource.persistent,
          :public => @new_resource.public,
          :target => @new_resource.target,
          :disk_type => @new_resource.disk_type,
          :source => @new_resource.source,
          :size => @new_resource.size,
          :fs_type => @new_resource.fs_type
        }

        if exists?
          if @image.name == image_config[:name] &&
             @image['PATH'] == image_config[:path] &&
             @image['TEMPLATE/DRIVER'] == image_config[:driver] &&
             @image['TEMPLATE/DESCRIPTION'] == image_config[:description] &&
             @image['DATASTORE_ID'] == image_config[:datastore_id]
            action_handler.report_progress("image '#{@new_resource.name}' (ID: #{@image.id}) already exists - (up to date)")
          else
            fail "image '#{new_resource.name}' already exists, but it is not the same image"
          end
        else
          action_handler.perform_action "upload image '#{@new_resource.name}'" do
            if @new_resource.image_file
              begin
                success = false
                pid = nil
                trap("CLD") do
                  cpid = Process.wait
                  fail "Could not start HTTP server on port #{@new_resource.http_port}" if cpid == pid && !success
                end
                pid = Process.spawn("python -m SimpleHTTPServer #{@new_resource.http_port}",
                  :chdir => ::File.dirname(@new_resource.image_file),
                  STDOUT => "/dev/null",
                  STDERR => "/dev/null",
                  :pgroup => true)
                new_driver.one.upload_img(image_config)
                success = true
                @new_resource.updated_by_last_action(true)
              ensure
                system("sudo kill -9 -#{pid}")
              end
            else
              new_driver.one.upload_img(image_config)
              @new_resource.updated_by_last_action(true)
            end
          end
        end
      end

      action :download do
        new_driver = driver

        action_handler.perform_action "downloaded image '#{@new_resource.image_file}" do
          download_url = ENV['ONE_DOWNLOAD'] || @new_resource.download_url
          fail %('download_url' is a required attribute.
            You can get the value for 'download_url' by loging into your OpenNebula CLI
            and reading the ONE_DOWNLOAD environment variable) if download_url.nil?
          # You can get the value for 'download_url' by loging into your OpenNebula CLI and reading the ONE_DOWNLOAD environment variable" if download_url.nil?
          image = new_driver.one.get_resource(:image, !@new_resource.image_id.nil? ? { :id => @new_resource.image_id } : { :name => @new_resource.name })
          fail "Image 'NAME: #{@new_resource.name}/ID: #{@new_resource.image_id}' does not exist" if image.nil?
          local_path = @new_resource.image_file || ::File.join(Chef::Config[:file_cache_path], "#{@new_resource.name}.qcow2")
          fail "Will not overwrite an existing file: #{local_path}" if ::File.exist?(local_path)
          command = "curl -o #{local_path} #{download_url}/#{::File.basename(::File.dirname(image['SOURCE']))}/#{::File.basename(image['SOURCE'])}"
          rc = system(command)
          fail rc if rc.nil?
          fail "ERROR: #{rc}" unless rc
          system("chmod 777 #{local_path}")
          Chef::Log.info("Image downloaded from OpenNebula to: #{local_path}")
          @new_resource.updated_by_last_action(true)
        end
      end

      protected

      def driver
        if current_driver && current_driver.driver_url != new_driver.driver_url
          fail "Cannot move '#{machine_spec.name}' from #{current_driver.driver_url} to #{new_driver.driver_url}: machine moving is not supported.  Destroy and recreate."
        end
        fail "Driver not specified for one_image #{new_resource.name}" unless new_driver
        new_driver
      end

      def new_driver
        run_context.chef_provisioning.driver_for(new_resource.driver)
      end

      def current_driver
        run_context.chef_provisioning.driver_for(run_context.chef_provisioning.current_driver) if run_context.chef_provisioning.current_driver
      end
    end
  end
end
