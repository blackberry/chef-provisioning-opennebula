require 'chef/provisioning/opennebula_driver'

one_image "OpenNebula-bootstrap-img" do
 machine_id 'OpenNebula-bootstrap-vm'
 action :attach
end