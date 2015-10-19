require 'chef/provider/one_vnet_lease'

class Chef::Resource::OneVnetLease < Chef::Resource::LWRPBase
  self.resource_name = 'one_vnet_lease'

  attribute :mac_ip, :kind_of => String, :name_attribute => true
  attribute :vnet, :kind_of => [String, Integer], :required => true
  attribute :ar_id, :kind_of => Integer, :default => -1

  attribute :driver

  actions :hold, :release
  default_action :hold

  def initialize(*args)
    super
    @driver = run_context.chef_provisioning.current_driver
  end
end
