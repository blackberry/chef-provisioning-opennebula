require 'chef/provisioning/opennebula_driver'

one_image "OpenNebula-bootstrap-img" do
  size 2048
  datastore_id 103
  action :create
end