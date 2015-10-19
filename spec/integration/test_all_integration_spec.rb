require 'spec_helper'
require 'chef/provisioning/opennebula_driver'

describe "create_one_template_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("create_one_template_spec.rb",
    "Creating template OpenNebula-test-tpl",
    "Template OpenNebula-test-tpl already exists") }
end

describe "instantiate_one_template_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("instantiate_one_template_spec.rb",
    "Creating instances from template",
    "Instance with name 'OpenNebula-test-1-vm' already exists") }
end

describe "create_bootstrap_vm_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("create_bootstrap_vm_spec.rb",
    "Creating VM OpenNebula-bootstrap-vm",
    "VM OpenNebula-bootstrap-vm exists. Rebooting...") }
end

describe "create_one_image_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("create_one_image_spec.rb",
    "Waiting for image 'OpenNebula-bootstrap-img' to be READY",
    "Image 'OpenNebula-bootstrap-img' is already in READY state") }
end

describe "attach_one_image_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("attach_one_image_spec.rb",
    "Disk not attached. Attaching...",
    "Disk is already attached") }
end

describe "snapshot_one_image_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("snapshot_one_image_spec.rb",
    "Creating snapshot from 'OpenNebula-bootstrap-vm'",
    "Snapshot image 'OpenNebula-snap-1-img' already exists") }
end

describe "converge_bootstrap_vm_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("converge_bootstrap_vm_spec.rb") }
end

# deploys two test backend VM's
describe "snapshot_two_image_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("snapshot_two_image_spec.rb",
    "Creating snapshot from 'OpenNebula-bootstrap-vm'",
    "Snapshot image 'OpenNebula-snap-1-img' already exists") }
end

describe "create_back_one_vm_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("create_back_one_vm_spec.rb",
    "Creating VM OpenNebula-back-1-vm",
    "VM OpenNebula-back-1-vm exists. Rebooting...") }
end

describe "attach_back_one_vm_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("attach_back_one_vm_spec.rb",
    "Disk not attached. Attaching...",
    "Disk is already attached") }
end

describe "converge_back_one_vm_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("converge_back_one_vm_spec.rb") }
end

describe "create_back_two_vm_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("create_back_two_vm_spec.rb",
    "Creating VM OpenNebula-back-2-vm",
    "VM OpenNebula-back-2-vm exists. Rebooting...") }
end

describe "attach_back_two_vm_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("attach_back_two_vm_spec.rb",
    "Disk not attached. Attaching...",
    "Disk is already attached") }
end

describe "converge_back_two_vm_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("converge_back_two_vm_spec.rb") }
end

# cleans up all test VMs/templates/images after testing
# assuming all other tests work as intended, this test will pass
# in the event a previous test failed, this test will also fail
describe "delete_all_spec.rb", :type => :recipe do
  it { is_expected.to converge_test_recipe("delete_all_spec.rb", nil, "does not exist") }
end