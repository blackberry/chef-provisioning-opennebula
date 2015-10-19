require 'chef/provisioning/opennebula_driver'

machine "OpenNebula-back-2-vm" do
  from_image "OpenNebula-snap-2-img"
  action :ready
end