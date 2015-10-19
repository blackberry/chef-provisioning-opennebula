require 'opennebula'

require 'opennebula/document'

module OpenNebula
    class CustomObject < Document

        DOCUMENT_TYPE = 555

    end
end

class Chef
module Provisioning
module OpenNebulaDriver
class OneLib
  attr_accessor :client

  def initialize(credentials, endpoint, options = {})
    @client = OpenNebula::Client.new(credentials, endpoint, options)
    rc = client.get_version()
    raise rc.message if OpenNebula.is_error?(rc)
  end

  # TODO: add filtering to pool retrieval (type, start, end, user)
  def get_pool(type)
    raise "pool type must be specified" if type.nil?
    case type
    when 'vm'
      OpenNebula::VirtualMachinePool.new(@client)
    when 'img'
      OpenNebula::ImagePool.new(@client, -1)
    when 'tpl'
      OpenNebula::TemplatePool.new(@client, -1)
    when 'user'
      OpenNebula::UserPool.new(@client)
    else
      raise "Invalid pool type specified. Must be one of: 'img', 'vm' or 'tpl'"
    end
  end

  def get_resource(resource_type, filter = {})
    if filter.empty?
      Chef::Log.warn("get_resource: 'name' or 'id' must be provided")
      return nil
    end
    pool = get_pool(resource_type)
    pool.info!(-2, filter[:id].to_i, filter[:id].to_i) if filter[:id]
    return pool.first if filter[:id]

    raise "Resource name is not defined" if !filter[:name]
    name = filter[:name]
    pool.info!(-2, -1, -1)
    pool.each do |res|
      # not sure about the id and name check or if it should only be id
      if name and res.name == name
        Chef::Log.debug("resource_exists: #{res.name}  (#{res.id})")
        return res
      end
    end
    Chef::Log.warn("No resource found... #{filter}")
    nil
  end

  def allocate_vm(template)
    rc, vm = nil, nil
    # retry up to 3 times because OpenNebula sometimes fails
    3.times { |i|
      vm = OpenNebula::VirtualMachine.new(OpenNebula::VirtualMachine.build_xml, @client)
      if !OpenNebula.is_error?(vm)
        Chef::Log.debug(template)
        rc = vm.allocate(template)
        break if !OpenNebula.is_error?(rc)
      end
      Chef::Log.info("Retrying VM allocation...")
      sleep(1)
    }
    raise "#{rc.message}" if OpenNebula.is_error?(rc)
    vm
  end

  def wait_for_vm(id, end_state = nil)
    end_state ||= 'RUNNING'
    vm = get_resource('vm', {:id => id})
    raise "Did not find VM with ID: #{id}" if !vm
    while vm.lcm_state_str != end_state.upcase
      vm.info
      Chef::Log.debug("Waiting for VM '#{id}' to be in '#{end_state.upcase}' state: '#{vm.lcm_state_str}'")
      raise "'#{vm.name}'' failed.  Current state: #{vm.state_str}" if vm.state_str == 'FAILED' or vm.lcm_state_str == 'FAILURE'
      sleep(2)
    end
    vm
  end

  def allocate_img(name, size, ds_id, type = 'DATABLOCK', fstype = 'ext2', driver = 'qcow2', prefix = 'vd', persistent = false)
    img, rc = nil, nil

    template = <<-EOT
NAME       = #{name}
TYPE       = #{type}
FSTYPE     = #{fstype}
SIZE       = #{size}
PERSISTENT = #{persistent ? 'YES' : 'NO'}

DRIVER     = #{driver}
DEV_PREFIX = #{prefix}
EOT

    2.times {
      img = OpenNebula::Image.new(OpenNebula::Image.build_xml, @client)
      rc = img
      if !OpenNebula.is_error?(rc)
        rc = img.allocate(template, ds_id)
        if !OpenNebula.is_error?(rc)
          break
        else
          Chef::Log.error(rc.message)
        end
      else
        Chef::Log.error(rc.message)
      end
      sleep(3)
    }
    Chef::Log.debug("Allocated disk image #{name} (#{img.id})") if !OpenNebula.is_error?(rc)
    raise "Failed to allocate image #{name}" if OpenNebula.is_error?(rc)
    img
  end

  def wait_for_img(name, img_id)
    rc, cur_state, image = nil, nil, nil
    state = 'INIT'
    pool = get_pool('img')
    while state == 'INIT' or state == 'LOCKED'
      pool.info!(-2, img_id, img_id)
      pool.each do |img|
        if img.id == img_id
          cur_state = img.state_str
          image = img
          Chef::Log.debug("Image #{img_id} state: '#{cur_state}'")
          state = cur_state
          break
        end
      end
      sleep(2)
    end
    raise "Failed to create #{name} image. State = '#{state}'" if state != 'READY'
    Chef::Log.info("Image #{name} is in READY state")
    image
  end

  def get_disk_id(vm, disk_name)
    raise "VM cannot be nil" if vm.nil?
    disk_id = nil
    vm.each('TEMPLATE/DISK') { |disk|
      disk_id = disk['DISK_ID'].to_i if disk['IMAGE'] == disk_name
    }
    disk_id
  end

  def allocate_template(template_name, template_str)
    rc, tpl = nil, nil

    2.times {
      tpl = OpenNebula::Template.new(OpenNebula::Template.build_xml, @client)
      rc = tpl
      if !OpenNebula.is_error?(rc)
        rc = tpl.allocate("#{template_str}")
        if !OpenNebula.is_error?(rc)
          break
        else
          Chef::Log.error(rc.message)
        end
      else
        Chef::Log.error(rc.message)
      end
      sleep(3)
    }
    Chef::Log.debug("Allocated template #{template_name} (#{tpl.id})") if !OpenNebula.is_error?(rc)
    raise "Failed to allocate template #{template_name}" if OpenNebula.is_error?(rc)
    tpl
  end

  def recursive_merge(dest, source)
    source.each { |k,v|
      if source[k].kind_of?(Hash)
        if dest[k].kind_of?(Array)
          dest[k] = v.dup
        else
          dest[k] = {} if !dest[k]
          recursive_merge(dest[k], v)
        end
      elsif source[k].kind_of?(Array)
        dest[k] = v.dup
      else
        dest[k] = v
      end
    }
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
    if !options[:template_name].nil? or !options[:template_id].nil?
      t = get_resource('tpl', { :name => options[:template_name] }) if options[:template_name]
      t = get_resource('tpl', { :id => options[:template_id] }) if options[:template_id]
      raise "Template '#{options}' does not exist" if t.nil?
      t_hash = t.to_hash["VMTEMPLATE"]["TEMPLATE"]
    elsif !options[:template_file].nil?
      rc, doc = nil, nil
      doc = OpenNebula::CustomObject.new(OpenNebula::CustomObject.build_xml, @client)
      if !OpenNebula.is_error?(doc)
        rc = doc.allocate("#{File.read(options[:template_file])}")
        raise "ERROR allocating OpenNebula document: #{rc.message}" if OpenNebula.is_error?(rc)
        doc.info!
        t_hash = doc.to_hash['DOCUMENT']['TEMPLATE']
        doc.delete
      end
    elsif !options[:template].nil?
      Chef::Log.debug("TEMPLATE_JSON: #{options[:template]}")
      t_hash = options[:template]
      tpl = create_template(options[:template])
    else
      raise "To create a VM you must specify one of ':template', ':template_id', ':template_name', or ':template' options in ':bootstrap_options'"
    end
    raise "Inavlid VM template : #{t_hash}" if t_hash.nil? or t_hash.empty?
    recursive_merge(t_hash, options[:user_variables]) if options[:user_variables]
    t_hash['NAME'] = options[:one_vm_name_fqdn] ? name : name.split('.')[0]
    tpl = create_template(t_hash)
    Chef::Log.debug(tpl)
    tpl
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
    t.each { |k,v|
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
        v.each { |e|
          tpl << "#{k} = [\n"
          tpl << create_template(e, (level + 1))
          tpl << "]\n"
        }
      else
        comma = (index < count) && level > 0
        level.times { tpl << "  " }
        tpl << "#{k} = \"#{v}\"" << (comma ? ",\n" : "\n")
        index = index + 1
      end
    }
    tpl
  end
end
end
end
end
