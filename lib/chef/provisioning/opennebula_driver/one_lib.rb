# Copyright 2015, BlackBerry, Inc.
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

require 'opennebula'

require 'opennebula/document'

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
  # Module extention.
  #
  module Provisioning
    #
    # Module extention.
    #
    module OpenNebulaDriver
      #
      # Implementation.
      #
      class OneLib
        attr_accessor :client

        def initialize(credentials, endpoint, options = {})
          @client = OpenNebula::Client.new(credentials, endpoint, options)
          rc = @client.get_version
          fail rc.message if OpenNebula.is_error?(rc)
        end

        # TODO: add filtering to pool retrieval (type, start, end, user)
        def get_pool(type)
          fail "pool type must be specified" if type.nil?
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
          when 'img'
            OpenNebula::ImagePool.new(@client, -1)
          when 'secgroup'
            OpenNebula::SecurityGroupPool.new(@client)
          when 'tpl'
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
            fail "Invalid pool type specified."
          end
        end

        def get_resource(resource_type, filter = {})
          if filter.empty?
            Chef::Log.warn("get_resource: 'name' or 'id' must be provided")
            return nil
          end
          pool = get_pool(resource_type)

          if resource_type != 'user' && filter[:id] && !filter[:id].nil?
            pool.info!(-2, filter[:id].to_i, filter[:id].to_i)
            return pool.first
          end

          if resource_type == 'user'
            pool.info
          else
            pool.info!(-2, -1, -1) if resource_type != 'user'
          end
          resources = []
          pool.each do |res|
            resources << res if res.name == filter[:name]
          end
          return nil if resources.size == 0
          return resources[0] if resources.size == 1
          resources
        end

        def allocate_vm(template)
          vm = OpenNebula::VirtualMachine.new(OpenNebula::VirtualMachine.build_xml, @client)
          fail "#{vm.message}" if OpenNebula.is_error?(vm)
          Chef::Log.debug(template)
          rc = vm.allocate(template)
          fail "#{rc.message}" if OpenNebula.is_error?(rc)
          vm
        end

        def wait_for_vm(id, end_state = nil)
          end_state ||= 'RUNNING'
          vm = get_resource('vm', :id => id)
          fail "Did not find VM with ID: #{id}" unless vm
          while vm.lcm_state_str != end_state.upcase
            vm.info
            Chef::Log.debug("Waiting for VM '#{id}' to be in '#{end_state.upcase}' state: '#{vm.lcm_state_str}'")
            fail "'#{vm.name}'' failed.  Current state: #{vm.state_str}" if vm.state_str == 'FAILED' || vm.lcm_state_str == 'FAILURE'
            sleep(2)
          end
          vm
        end

        def upload_img(name, ds_id, path, driver, description, type, prefix, persistent, pub, target, disk_type, source, size, fstype)
          template = <<-EOTPL
NAME        = #{name}
PATH        = \"#{path}\"
DRIVER      = #{driver}
DESCRIPTION = \"#{description}\"
EOTPL

          template << "TYPE        = #{type}\n" unless type.nil?
          template << "PERSISTENT  = YES\n" if !persistent.nil? && persistent
          template << "DEV_PREFIX  = #{prefix}\n" unless prefix.nil?
          template << "PUBLIC      = YES\n" if !pub.nil? && pub
          template << "TARGET      = #{target}\n" unless target.nil?
          template << "DISK_TYPE   = #{disk_type}\n" unless disk_type.nil?
          template << "SOURCE      = #{source}\n" unless source.nil?
          template << "SIZE        = #{size}" unless size.nil?
          template << "FSTYPE      = #{fstype}\n" unless fstype.nil?

          Chef::Log.debug("\n#{template}")

          image = OpenNebula::Image.new(OpenNebula::Image.build_xml, @client)
          fail image.message if OpenNebula.is_error?(image)
          rc = image.allocate(template, ds_id)
          fail rc.message if OpenNebula.is_error?(rc)
          Chef::Log.debug("Waiting for image '#{name}' (#{image.id}) to be ready")
          wait_for_img(name, image.id)
        end

        def allocate_img(name, size, ds_id, type, fstype, driver, prefix, persistent)
          template = <<-EOT
NAME       = #{name}
TYPE       = #{type}
FSTYPE     = #{fstype}
SIZE       = #{size}
PERSISTENT = #{persistent ? 'YES' : 'NO'}

DRIVER     = #{driver}
DEV_PREFIX = #{prefix}
EOT

          img = OpenNebula::Image.new(OpenNebula::Image.build_xml, @client)
          fail img.message if OpenNebula.is_error?(img)

          rc = img.allocate(template, ds_id)
          fail rc.message if OpenNebula.is_error?(rc)

          Chef::Log.debug("Allocated disk image #{name} (#{img.id})")
          img
        end

        def wait_for_img(name, img_id)
          cur_state = nil
          image = nil
          state = 'INIT'
          pool = get_pool('img')
          while state == 'INIT' || state == 'LOCKED'
            pool.info!(-2, img_id, img_id)
            pool.each do |img|
              next unless img.id == img_id
              cur_state = img.state_str
              image = img
              Chef::Log.debug("Image #{img_id} state: '#{cur_state}'")
              state = cur_state
              break
            end
            sleep(2)
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

        def allocate_vnet(vnet_name, cluster_id, template_str)
          vnet = OpenNebula::Vnet.new(OpenNebula::Vnet.build_xml, @client)
          rc = vnet.allocate(template_str, cluster_id) unless OpenNebula.is_error?(vnet)
          fail "Failed to allocate vnet #{vnet_name}: #{rc.message}" if OpenNebula.is_error?(rc)
          vnet
        end

        def allocate_template(template_name, template_str)
          tpl = OpenNebula::Template.new(OpenNebula::Template.build_xml, @client)
          rc = tpl
          rc = tpl.allocate("#{template_str}") unless OpenNebula.is_error?(rc)
          fail "Failed to allocate template #{template_name}: #{rc.message}" if OpenNebula.is_error?(rc)
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
            fail "To create a VM you must specify one of ':template', ':template_id', ':template_name', or ':template' options in ':bootstrap_options'"
          end
          fail "Inavlid VM template : #{t_hash}" if t_hash.nil? || t_hash.empty?
          tpl_updates = options[:template_options] || {}
          if options[:user_variables]
            Chef::Log.warn("':user_variables' will be deprecated in next version in favour of ':template_options'") if options.key?(:user_variables)
            recursive_merge(tpl_updates, options[:user_variables])
          end
          recursive_merge(t_hash, tpl_updates) unless tpl_updates.empty?
          t_hash['NAME'] = options[:one_vm_name_fqdn] ? name : name.split('.')[0]
          tpl = create_template(t_hash)
          Chef::Log.debug(tpl)
          tpl
        end

        def template_from_one(options)
          t = get_resource('tpl', :name => options[:template_name]) if options[:template_name]
          t = get_resource('tpl', :id => options[:template_id]) if options[:template_id]
          fail "Template '#{options}' does not exist" if t.nil?
          t.to_hash["VMTEMPLATE"]["TEMPLATE"]
        end

        def template_from_file(options)
          t_hash = nil
          doc = OpenNebula::CustomObject.new(OpenNebula::CustomObject.build_xml, @client)
          unless OpenNebula.is_error?(doc)
            rc = doc.allocate("#{File.read(options[:template_file])}")
            fail "Failed to allocate OpenNebula document: #{rc.message}" if OpenNebula.is_error?(rc)
            doc.info!
            t_hash = doc.to_hash['DOCUMENT']['TEMPLATE']
            doc.delete
          end
          t_hash
        end

        def template_from_hash(options)
          Chef::Log.debug("TEMPLATE_JSON: #{options[:template]}")
          options[:template]
        end

        #
        # This method will create a VM template from parameters provided
        # in the 't' Hash.  The hash must have equivalent structure as the
        # VM template.
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
              tpl << "#{k} = \"#{v}\"" << (comma ? ",\n" : "\n")
              index += 1
            end
          end
          tpl
        end
      end
    end
  end
end
