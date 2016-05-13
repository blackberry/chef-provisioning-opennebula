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
# Sample Document definition.
#
module OpenNebula
  #
  # Implementation.
  #
  class CustomObject < Document
    DOCUMENT_TYPE = 555
  end
end

#
# Implementation.
#
class Chef
  #
  # Module extension.
  #
  module Provisioning
    #
    # Module extension.
    #
    module OpenNebulaDriver
      #
      # ONE error.
      #
      class OpenNebulaException < Exception
      end

      #
      # Implementation.
      #
      class OneLib
        attr_reader :client, :version_ge_4_14

        def initialize(args)
          @client = OpenNebula::Client.new(args[:credentials], args[:endpoint], args[:options])
          rc = @client.get_version
          raise OpenNebulaException, rc.message if OpenNebula.is_error?(rc)
          gem_version = Gem.loaded_specs['opennebula'].version.to_s.split('.').map(&:to_i)
          @version_ge_4_14 = gem_version[0] > 4 || (gem_version[0] == 4 && gem_version[1] >= 14)
        end

        # This function provides a more readable way to return a
        # OpenNebula::*Pool back to a caller.  The caller simply needs
        # to pass the pool type in symbol form to us, and we send back
        # the pool.  The idea is that passing :template will give us
        # back OpenNebula::TemplatePool, etc. for consistency with
        # the OpenNebula API calls.  Note that we are still supporting
        # the old API, while logging a warning that the old format
        # is deprecated.  Users should expect the old format to disappear
        # in a future release.
        def get_pool(type)
          fail "pool type must be specified" if type.nil?
          key = type.capitalize
          key = :SecurityGroup  if key == :Securitygroup
          key = :VirtualMachine if key == :Virtualmachine
          key = :VirtualNetwork if key == :Virtualnetwork
          if key == :Documentpooljson # Doesn't match the template below
            return OpenNebula::DocumentPoolJSON.new(@client)
          end

          pool_class = Object.const_get("OpenNebula::#{key}Pool")
          pool_class.new(@client)
        rescue NameError
          _get_pool(type.to_s) # This will raise an exception if invalid.
        end

        # TODO: add filtering to pool retrieval (type, start, end, user)
        def _get_pool(type)
          Chef::Log.warn("Use of deprecated pool type '#{type}' detected. " \
                         "Switch to symbol form; i.e. '[:#{type}]' to use the " \
                         "'OpenNebula::#{type}Pool'.")

          case type
          when 'acl'
            OpenNebula::AclPool.new(@client)
          when 'cluster'
            OpenNebula::ClusterPool.new(@client)
          when 'datastore'
            OpenNebula::DatastorePool.new(@client)
          when 'doc'
            OpenNebula::DocumentPool.new(@client)
          when 'jsondoc'
            OpenNebula::DocumentPoolJSON.new(@client)
          when 'group'
            OpenNebula::GroupPool.new(@client)
          when 'host'
            OpenNebula::HostPool.new(@client)
          when 'image', 'img'
            OpenNebula::ImagePool.new(@client, -1)
          when 'secgroup'
            OpenNebula::SecurityGroupPool.new(@client)
          when 'tpl', 'vmtemplate', 'template'
            OpenNebula::TemplatePool.new(@client, -1)
          when 'user'
            OpenNebula::UserPool.new(@client)
          when 'vdc'
            OpenNebula::VdcPool.new(@client)
          when 'vm'
            OpenNebula::VirtualMachinePool.new(@client)
          when 'vnet'
            OpenNebula::VirtualNetworkPool.new(@client)
          else
            fail "Invalid pool type '#{type}' specified."
          end
        end
        private :_get_pool

        # TODO: Always return an array
        def get_resource(resource_type, filter = {})
          fail "resource_type must be specified" if resource_type.nil?

          # Ensure the hash key is correct when searching
          hash_key = resource_type.to_s.upcase
          hash_key = 'VMTEMPLATE' if hash_key == 'TPL' || hash_key == 'TEMPLATE'

          if filter.empty?
            Chef::Log.warn("get_resource: 'name' or 'id' must be provided")
            return nil
          end
          pool = get_pool(resource_type)

          if resource_type.to_s != 'user' && filter[:id] && !filter[:id].nil?
            pool.info!(-2, filter[:id].to_i, filter[:id].to_i)
            return pool.first
          end

          if resource_type.to_s == 'user'
            pool.info
          else
            pool.info!(-2, -1, -1)
          end
          resources = []
          pool.each do |res|
            next unless res.name == filter[:name]
            next if filter[:uname] && res.to_hash[hash_key]['UNAME'] != filter[:uname]
            resources << res
          end
          return nil if resources.empty?
          return resources[0] if resources.size == 1
          resources
        end

        def allocate_vm(template)
          vm = OpenNebula::VirtualMachine.new(OpenNebula::VirtualMachine.build_xml, @client)
          raise OpenNebulaException, vm.message if OpenNebula.is_error?(vm)

          Chef::Log.debug(template)
          rc = vm.allocate(template)
          raise OpenNebulaException, rc.message if OpenNebula.is_error?(rc)
          vm
        end

        def wait_for_vm(id, end_state = nil)
          end_state ||= 'RUNNING'
          vm = get_resource(:virtualmachine, :id => id)
          fail "Did not find VM with ID: #{id}" unless vm

          # Wait up to 10 min for the VM to be ready
          rc = retryable_operation("wait for VM #{id} to be ready", 600, 2) do
            vm.info
            if vm.lcm_state_str != 'LCM_INIT'
              short_lcm = OpenNebula::VirtualMachine::SHORT_LCM_STATES[vm.lcm_state_str]
              fail "'#{vm.name}'' failed.  Current state: #{vm.lcm_state_str}" if short_lcm == 'fail'
            end
            fail "'#{vm.name}'' failed.  Current state: #{vm.state_str}" if vm.state_str == 'FAILED'
            Chef::Log.info("current state: '#{vm.lcm_state_str}'  short: '#{short_lcm}'")
            OpenNebula::Error.new("Waiting") unless vm.lcm_state_str.casecmp(end_state) == 0
          end
          fail "wait_for_vm timed out: '#{id}'" if rc.nil?
          vm
        end

        # Retry an OpenNebula operation until the timeout expires.  Will always try at least once.
        def retryable_operation(msg = "operation", timeout = 15, delay = 2)
          return nil unless block_given?
          start = Time.now
          rc = nil
          loop do
            rc = yield
            return true unless OpenNebula.is_error?(rc)
            Chef::Log.info(msg)
            sleep delay
            break if (Time.now - start) > timeout
          end
          Chef::Log.info("Timed out waiting for OpenNebula operation.  Got error #{rc.message} from OpenNebula.")
          nil
        end

        def rename_vm(res, name)
          rc = res.rename(name)
          raise OpenNebulaException, rc.message if OpenNebula.is_error?(rc)
        end

        def upload_img(img_config)
          template = <<-EOTPL
NAME        = #{img_config[:name]}
PATH        = \"#{img_config[:path]}\"
DRIVER      = #{img_config[:driver]}
DESCRIPTION = \"#{img_config[:description]}\"
          EOTPL

          template << "TYPE        = #{img_config[:type]}\n" unless img_config[:type].nil?
          template << "DEV_PREFIX  = #{img_config[:prefix]}\n" unless img_config[:prefix].nil?
          template << "TARGET      = #{img_config[:target]}\n" unless img_config[:target].nil?
          template << "DISK_STYPE  = #{img_config[:disk_type]}\n" unless img_config[:disk_type].nil?
          template << "SOURCE      = #{img_config[:source]}\n" unless img_config[:source].nil?
          template << "SIZE        = #{img_config[:size]}\n" unless img_config[:size].nil?
          template << "FSTYPE      = #{img_config[:fs_type]}\n" unless img_config[:fs_type].nil?
          template << "PUBLIC      = #{img_config[:public] ? 'YES' : 'NO'}\n" unless img_config[:public].nil?
          template << "PERSISTENT  = #{img_config[:persistent] ? 'YES' : 'NO'}\n" unless img_config[:persistent].nil?

          Chef::Log.debug("\n#{template}")
          image = OpenNebula::Image.new(OpenNebula::Image.build_xml, @client)
          raise OpenNebulaException, image.message if OpenNebula.is_error?(image)
          rc = image.allocate(template, img_config[:datastore_id].to_i)
          raise OpenNebulaException, rc.message if OpenNebula.is_error?(rc)
          Chef::Log.debug("Waiting for image '#{img_config[:name]}' (#{image.id}) to be ready")
          wait_for_img(img_config[:name], image.id)
          chmod_resource(image, img_config[:mode])
        end

        def chmod_resource(res = nil, octet = nil)
          rc = res.chmod_octet(octet) unless res.nil? || octet.nil?
          raise OpenNebulaException, rc.message if OpenNebula.is_error?(rc)
        end

        def allocate_img(img_config)
          template = <<-EOT
NAME       = #{img_config[:name]}
TYPE       = #{img_config[:type]}
FSTYPE     = #{img_config[:fstype]}
SIZE       = #{img_config[:size]}
PERSISTENT = #{img_config[:persistent] ? 'YES' : 'NO'}

DRIVER     = #{img_config[:driver]}
DEV_PREFIX = #{img_config[:prefix]}
          EOT

          img = OpenNebula::Image.new(OpenNebula::Image.build_xml, @client)
          raise OpenNebulaException, img.message if OpenNebula.is_error?(img)

          rc = img.allocate(template, img_config[:datastore_id])
          raise OpenNebulaException, rc.message if OpenNebula.is_error?(rc)

          Chef::Log.debug("Allocated disk image #{img_config[:name]} (#{img.id})")
          img
        end

        def wait_for_img(name, img_id)
          cur_state = nil
          image = nil
          state = 'INIT'
          pool = get_pool(:image)

          retryable_operation("wait for IMAGE #{img_id} to be ready", 600, 2) do
            pool.info!(-2, img_id, img_id)
            pool.each do |img|
              next unless img.id == img_id
              cur_state = img.state_str
              image = img
              Chef::Log.debug("Image #{img_id} state: '#{cur_state}'")
              state = cur_state
              break
            end
            OpenNebula::Error.new("Waiting") if state == 'INIT' || state == 'LOCKED'
          end
          fail "Failed to create #{name} image. State = '#{state}'" if state != 'READY'
          Chef::Log.info("Image #{name} is in READY state")
          image
        end

        def get_disk_id(vm, disk_name)
          fail "VM cannot be nil" if vm.nil?
          disk_id = nil
          vm.each('TEMPLATE/DISK') { |disk| disk_id = disk['DISK_ID'].to_i if disk['IMAGE'] == disk_name }
          disk_id
        end

        def allocate_vnet(template_str, cluster_id)
          vnet = OpenNebula::Vnet.new(OpenNebula::Vnet.build_xml, @client)
          rc = vnet.allocate(template_str, cluster_id) unless OpenNebula.is_error?(vnet)
          raise OpenNebulaException, rc.message if OpenNebula.is_error?(rc)
          vnet
        end

        def update_template(template_id, template_str)
          template = OpenNebula::Template.new(OpenNebula::Template.build_xml(template_id), @client)
          rc = template.update(template_str) unless OpenNebula.is_error?(template)
          raise OpenNebulaException, rc.message if OpenNebula.is_error?(rc)
          rc
        end

        def allocate_template(template_str)
          tpl = OpenNebula::Template.new(OpenNebula::Template.build_xml, @client)
          rc = tpl.allocate(template_str) unless OpenNebula.is_error?(tpl)
          raise OpenNebulaException, rc.message if OpenNebula.is_error?(rc)
          rc
        end

        def recursive_merge(dest, source)
          source.each do |k, v|
            if source[k].is_a?(Hash)
              if dest[k].is_a?(Array)
                dest[k] = v.dup
              else
                dest[k] = {} unless dest[k]
                recursive_merge(dest[k], v)
              end
            elsif source[k].is_a?(Array)
              dest[k] = v.dup
            else
              dest[k] = v
            end
          end
        end

        #
        # This will retrieve a VM template from one of the following locations:
        #   :template_name - template located in OpenNebula
        #   :template_id   - template located in OpenNebula
        #   :template_file - local file containing the VM template
        #   :template      - Hash containing equivalent structure as a VM template
        #
        def get_template(name, options)
          t_hash = nil
          if !options[:template_name].nil? || !options[:template_id].nil?
            t_hash = template_from_one(options)
          elsif !options[:template_file].nil?
            t_hash = template_from_file(options)
          elsif !options[:template].nil?
            t_hash = template_from_hash(options)
          else
            fail "To create a VM you must specify one of ':template', " \
                 "':template_id', or ':template_name' option " \
                 "in ':bootstrap_options'"
          end
          fail "Inavlid VM template : #{t_hash}" if t_hash.nil? || t_hash.empty?
          tpl_updates = options[:template_options] || {}
          if options[:user_variables]
            Chef::Log.warn("':user_variables' will be deprecated in next " \
                           "version in favour of ':template_options'")
            recursive_merge(tpl_updates, options[:user_variables])
          end
          recursive_merge(t_hash, tpl_updates) unless tpl_updates.empty?
          if options[:enforce_chef_fqdn]
            Chef::Log.warn(':enforce_chef_fqdn has been deprecated.  VM name ' \
                           'will be set to the machine resource name.')
          end
          # FQDN is the machine resource name, unless overridden by e.g. cloud-init
          t_hash['NAME'] = name
          unless t_hash['CONTEXT']['SSH_PUBLIC_KEY']
            t_hash['CONTEXT']['SSH_PUBLIC_KEY'] = "$USER[SSH_PUBLIC_KEY]"
          end
          unless t_hash['CONTEXT']['USER_DATA']
            t_hash['CONTEXT']['USER_DATA'] = "#cloud-config\n" \
                                             "manage_etc_hosts: true\n"
          end
          tpl = create_template(t_hash)
          Chef::Log.debug(tpl)
          tpl
        end

        def template_from_one(options)
          t = get_resource(:template, :name => options[:template_name]) if options[:template_name]
          t = get_resource(:template, :id => options[:template_id]) if options[:template_id]
          fail "Template '#{options}' does not exist" if t.nil?
          t.to_hash["VMTEMPLATE"]["TEMPLATE"]
        end

        def template_from_file(options)
          t_hash = nil
          doc = OpenNebula::CustomObject.new(OpenNebula::CustomObject.build_xml, @client)
          unless OpenNebula.is_error?(doc)
            rc = doc.allocate(File.read(options[:template_file]).to_s)
            fail "Failed to allocate OpenNebula document: #{rc.message}" if OpenNebula.is_error?(rc)
            doc.info!
            t_hash = doc.to_hash['DOCUMENT']['TEMPLATE']
            doc.delete
          end
          t_hash
        end

        def template_from_hash(options)
          options[:template]
        end

        #
        # This method will create a VM template from parameters provided
        # in the 't' Hash. The hash must have equivalent structure as the
        # VM template.
        #
        # We considered using OpenNebulaHelper::create_template for this,
        # however it would require a backwards compatibility shim and/or
        # making breaking changes to the API.  In particular, our method is
        # more attractive due to the nested nature of our Hash, versus specifying
        # a long string for the :context attribute with embedded newlines.
        # Our strategy provides a way to override specific values, while this is
        # difficult to accomplish with OpenNebulaHelper::create_template.
        #
        # Current template hash:
        # {
        #   "NAME" => "baz"
        #   "CPU" => "1",
        #   "VCPU" => "1",
        #   "MEMORY" => "512",
        #   "OS" => {
        #     "ARCH" => "x86_64"
        #   },
        #   "GRAPHICS" => {
        #     "LISTEN" => "0.0.0.0",
        #     "TYPE" => "vnc"
        #   },
        #   "CONTEXT" => {
        #     "FOO" => "BAR",
        #     "BAZ" => "QUX"
        #     "HOSTNAME" => "$NAME",
        #     "SSH_PUBLIC_KEY" => "$USER[SSH_PUBLIC_KEY]",
        #     "NETWORK" => "YES"
        #   }
        # }
        #
        # Using OpenNebulaHelper::create_template:
        # {
        #   :name => 'baz'
        #   :cpu => 1,
        #   :vcpu => 1,
        #   :memory => 512,
        #   :arch => 'x86_64',
        #   :vnc => true,
        #   :context => "FOO=\"BAR\"\nBAZ=\"QUX\"\nHOSTNAME=\"$NAME\"",
        #   :ssh => true,
        #   :net_context => true
        # }
        #
        def create_template(t, level = 0)
          tpl = ""
          count = t.size
          index = 1
          t.each do |k, v|
            if v.is_a?(Hash)
              level.times { tpl << "  " }
              # DISK and NIC is just for backward compatibility
              # it should be replaced by Array
              k = 'DISK' if k =~ /^DISK/
              k = 'NIC' if k =~ /^NIC/
              tpl << "#{k} = [\n"
              tpl << create_template(v, (level + 1))
              (level - 1).times { tpl << "  " }
              tpl << "]\n"
            elsif v.is_a?(Array)
              level.times { tpl << "  " }
              v.each do |e|
                tpl << "#{k} = [\n"
                tpl << create_template(e, (level + 1))
                tpl << "]\n"
              end
            else
              comma = (index < count) && level > 0
              level.times { tpl << "  " }
              txt = v.is_a?(String) ? "#{k} = \"#{v.gsub(/(?<!\\)\"/, '\"')}\"" : "#{k} = \"#{v}\""
              tpl << txt
              tpl << (comma ? ",\n" : "\n")
              index += 1
            end
          end
          tpl
        end
      end
    end
  end
end
