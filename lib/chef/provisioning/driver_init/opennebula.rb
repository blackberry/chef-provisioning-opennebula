require 'chef/provisioning/opennebula_driver/driver'

Chef::Provisioning.register_driver_class("opennebula", Chef::Provisioning::OpenNebulaDriver::Driver)
