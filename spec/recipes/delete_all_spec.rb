require 'chef/provisioning/opennebula_driver'
  
one_template "OpenNebula-test-tpl" do
  action :delete
end

machine "OpenNebula-tpl-1-vm" do
  action :destroy
end

machine "OpenNebula-bootstrap-vm" do
  action :destroy
end

one_image "OpenNebula-bootstrap-img" do
  action :destroy
end

machine "OpenNebula-back-1-vm" do
  action :destroy
end

machine "OpenNebula-back-2-vm" do
  action :destroy
end

one_image "OpenNebula-snap-1-img" do
  action :destroy
end

one_image "OpenNebula-snap-2-img" do
  action :destroy
end