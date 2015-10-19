require 'chef/provisioning/opennebula_driver'

machine "OpenNebula-back-1-vm" do
  from_image "OpenNebula-snap-1-img"
  action :ready
end