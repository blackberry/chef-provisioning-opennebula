require 'chef/provider/one_template'

class Chef::Resource::OneTemplate < Chef::Resource::LWRPBase
  self.resource_name = 'one_template'

  attribute :template, :kind_of => Hash
  attribute :template_file, :kind_of => String
  attribute :count, :kind_of => Integer
  attribute :instances, :kind_of => [String, Array]
  attribute :driver

  actions :create, :delete, :instantiate
  default_action :create
    
  def initialize(*args)
    super
    @chef_environment = run_context.cheffish.current_environment
    @chef_server = run_context.cheffish.current_chef_server
    @driver = run_context.chef_provisioning.current_driver
  end
end
