require 'chef/provisioning/opennebula_driver'

one_image "OpenNebula-snap-1-img" do
  machine_id "OpenNebula-bootstrap-vm"
  disk_id "OpenNebula-bootstrap-img"
  action :snapshot
end