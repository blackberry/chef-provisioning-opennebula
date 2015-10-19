require 'chef/provisioning/opennebula_driver'

one_image "OpenNebula-snap-2-img" do
 machine_id 'OpenNebula-back-2-vm'
 action :attach
end