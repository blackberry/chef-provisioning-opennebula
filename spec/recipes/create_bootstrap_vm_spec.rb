require 'chef/provisioning/opennebula_driver'

machine "OpenNebula-bootstrap-vm" do
  machine_options :bootstrap_options => ({
   :user_variables => {'MEMORY' => '2048', 'CONTEXT/TEST' => 'test'},
   :template_name  => 'OpenNebula-test-tpl'
   }),
  :ssh_user => 'local',
  :ssh_options => {
    :keys_only => false,
    :forward_agent => true,
    :use_agent => true,
    :user_known_hosts_file => '/dev/null'
  },
  :ssh_execute_options => {
    :prefix => 'sudo '
  },
  :cached_installer => true 
 action :ready
end