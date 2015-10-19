require 'chef/provider/one_vnet'

class Chef::Resource::OneVnet < Chef::Resource::LWRPBase
  self.resource_name = 'one_vnet'

  attribute :name, :kind_of => String, :name_attribute => true
  attribute :vnet_id, :kind_of => Integer
  attribute :network, :kind_of => Integer
  attribute :size, :kind_of => Integer, :default => 1
  attribute :mac_ip, :kind_of => String
  attribute :ar_id, :kind_of => Integer
  attribute :template_file, :kind_of => String
  attribute :cluster_id, :kind_of => Integer

  attribute :driver

  actions :reserve, :create, :delete
  default_action :reserve

  def initialize(*args)
    super
    @driver = run_context.chef_provisioning.current_driver
  end
end
