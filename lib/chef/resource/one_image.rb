require 'chef/provider/one_image'

class Chef::Resource::OneImage < Chef::Resource::LWRPBase
  self.resource_name = 'one_image'

  actions :allocate, :create, :destroy, :attach, :snapshot, :upload, :download
  default_action :create

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :size, :kind_of => Integer
  attribute :datastore_id, :kind_of => Integer
  attribute :driver_options, :kind_of => Hash
  attribute :type, :kind_of => String, :equal_to => ['OS', 'CDROM', 'DATABLOCK', 'KERNEL', 'RAMDISK', 'CONTEXT']
  attribute :description, :kind_of => String
  attribute :fs_type, :kind_of => String
  attribute :img_driver, :kind_of => String, :default => 'qcow2'
  attribute :prefix, :kind_of => String, :equal_to => ['vd', 'xvd', 'sd', 'hd']
  attribute :persistent, :kind_of => [ TrueClass, FalseClass ]
  attribute :public, :kind_of => [ TrueClass, FalseClass ]
  attribute :disk_type, :kind_of => String
  attribute :source, :kind_of => String
  attribute :target, :kind_of => String
  attribute :machine_id, :kind_of => [String, Integer]
  attribute :disk_id, :kind_of => [String, Integer]
  attribute :image_file, :kind_of => String
  attribute :driver
  
  attribute :download_url, :kind_of => String
  attribute :image_id, :kind_of => Integer

  def initialize(*args)
    super
    @chef_environment = run_context.cheffish.current_environment
    @chef_server = run_context.cheffish.current_chef_server
    @driver = run_context.chef_provisioning.current_driver
  end
end

