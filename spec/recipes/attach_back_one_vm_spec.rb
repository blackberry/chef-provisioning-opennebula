require 'chef/provisioning/opennebula_driver'

one_image "OpenNebula-snap-1-img" do
 machine_id 'OpenNebula-back-1-vm'
 action :attach
end