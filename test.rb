require 'chef/provisioning/opennebula_driver'

with_driver "opennebula",
  :credentials => "user:password"
  :credentials => "Mandolin:musici@n4",
#  :credentials => "bbsl-auto:theSt0ne6",
  :endpoint => "http://10.236.33.240/orion"

with_chef_server "https://chef-server.boggi.dev.orion.altus.bblabs", {
  :client_name => Chef::Config[:node_name],
  :signing_key_filename => Chef::Config[:client_key],
  :ssl_verify_mode => :verify_none
}
#  :client_name => 'admin',
#  :signing_key_filename => '/home/bbuczynski/.chef/chef-server-ha/admin.pem'
      

with_machine_options :bootstrap_options => {
    :template => {
      "HTTPBASE" => "http://orion-cli.orion.altus.bblabs.rim.net/~chef/context",
    #  "NAME" => "bbuczynski-test-vm",
    #  "NAME" => "bbuczynski-driver-test2",
      "MEMORY" => "2048",
      "CPU" => "1",
      "VCPU" => "1",
      "OS" => {
          "ARCH" => "x86_64"
      },
      "DISK" => {
          "IMAGE" => "Ubuntu-12.04.5-pre-prod-20141216",
          "IMAGE_UNAME" => "m_plumb",
          "DRIVER" => "qcow2"
      },
      "NIC" => {
        "NETWORK" => "PUB-52-10.236",
        "NETWORK_UNAME" => "neutrino"
      },
      "GRAPHICS" => {
            "LISTEN" => "0.0.0.0",
            "TYPE" => "vnc"
      },
      "CONTEXT" => {
            "NETWORK" => "YES",
            "HOSTNAME" => "$NAME",
            "INSTALL_CHEF_CLIENT_COMMAND" => "dpkg -E -i /mnt/chef-client.deb",
            "SSH_USER" => 'local',
            "SSH_PUBLIC_KEY" => "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD0kG8BM/wSQ4pN7Rb2ETneYgiEOZMiwOQ1ryxVSpNbHTDbVzp97uzMj6B/IJ62NMrAZQwFJeiCTAaJ0Z4Bo8D5aatt4algFEIdX9R31ZdJz1I5JeeMgbLcsnh9gToQ1MfLe/+nznsiQjK+/fFDwOBSDCQAULpxNC5aN1SCozE0y1NS1afiVotsJ/mtsqdQqq7x70OpnuiSzMF4Xovq2N/DUIkH0nuHGecq9EChITRvYvMf9G0eDBTFi4IsmcXE5rmqyhnBvJN0vRICzCUdQ2rmG+SjJ41sAN3rtskubjb59X54sRtYZrLZKw5KRGWzcdx7o8TtKokOkDo5wXD2FrRD root@chef-ws-bbuczynski-001",
    #        "SSH_PUBLIC_KEY" => "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAIEAgaA3GDtH38JPk7fh6s7pvX6BBcyLkgF7Wf/Le0zeEWqhv+LdM/m308ysFViGDrgqMQYFkSWrLW79XfDlYXVIlVcFzdQEj3tloFn3xOi5q5oVEqVxorXLaiZ5AIA8tG+1ENLHsA1zb57ECVJrMRhPdtYUDMtmoNJOapZJSkF+ihc= rsa-key-20150220",
            "FILES" => "$HTTPBASE/01_chef $HTTPBASE/../chef-client.deb"
      }
    }
  },
#with_machine_options :template_file => 'c:/chef/mandolin/chef-provisioning-opennebula/test.tpl',
#with_machine_options :template_name => 'bbuczynski-sous-frontend',
  :ssh_user => 'local',
  :ssh_options => {
#  :paranoid => false,
#  :auth_methods => ['publickey'],
#  :keys => [ File.open(File.expand_path('~/.ssh/id_rsa_new')).read ]
    :keys_only => false,
    :forward_agent => true,
    :use_agent => true,
    :user_known_hosts_file => '/dev/null'
  },
  :ssh_execute_options => {
    :prefix => 'sudo '
  },
  :cached_installer => true  

one_template "bbuczynski-test-tpl" do
  template  ({
    "HTTPBASE" => "http://orion-cli.orion.altus.bblabs.rim.net/~chef/context",
    "MEMORY" => "1024",
    "CPU" => "1",
    "VCPU" => "1",
    "OS" => {
        "ARCH" => "x86_64"
    },
    "DISK" => {
        "IMAGE" => "Ubuntu-12.04.5-pre-prod-20141216",
        "IMAGE_UNAME" => "m_plumb",
        "DRIVER" => "qcow2"
    },
    "NIC" => {
      "NETWORK" => "PUB-52-10.236",
      "NETWORK_UNAME" => "neutrino"
    },
    "GRAPHICS" => {
          "LISTEN" => "0.0.0.0",
          "TYPE" => "vnc"
    },
    "CONTEXT" => {
          "NETWORK" => "YES",
          "HOSTNAME" => "$NAME",
          "INSTALL_CHEF_CLIENT_COMMAND" => "dpkg -E -i /mnt/chef-client.deb",
          "SSH_USER" => 'local',
          "SSH_PUBLIC_KEY" => "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD0kG8BM/wSQ4pN7Rb2ETneYgiEOZMiwOQ1ryxVSpNbHTDbVzp97uzMj6B/IJ62NMrAZQwFJeiCTAaJ0Z4Bo8D5aatt4algFEIdX9R31ZdJz1I5JeeMgbLcsnh9gToQ1MfLe/+nznsiQjK+/fFDwOBSDCQAULpxNC5aN1SCozE0y1NS1afiVotsJ/mtsqdQqq7x70OpnuiSzMF4Xovq2N/DUIkH0nuHGecq9EChITRvYvMf9G0eDBTFi4IsmcXE5rmqyhnBvJN0vRICzCUdQ2rmG+SjJ41sAN3rtskubjb59X54sRtYZrLZKw5KRGWzcdx7o8TtKokOkDo5wXD2FrRD root@chef-ws-bbuczynski-001",
          "FILES" => "$HTTPBASE/01_chef $HTTPBASE/../chef-client.deb"
    }
  })
  action :create
end

machine "bbuczynski-bootstrap-vm" do
  machine_options :bootstrap_options => ({
   :user_variables => {'MEMORY' => '2048', 'CONTEXT/BOGGI' => 'test'},
   :template_name  => 'bbuczynski-test-tpl'
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

one_image "bbuczynski-bootstrap-img" do
  size 2048
  datastore_id 103
  action :create
end

one_image "bbuczynski-bootstrap-img" do
 machine_id 'bbuczynski-bootstrap-vm'
 action :attach
end

# one_image "bbuczynski-test-img-1" do
#   action :destroy
# end

one_image "bbuczynski-snap-1-img" do
  machine_id "bbuczynski-bootstrap-vm"
  disk_id "bbuczynski-bootstrap-img"
  action :snapshot
end

machine "bbuczynski-bootstrap-vm" do
  files ({
    "/etc/chef/client.rb" => "/home/bbuczynski/PROJECT_FILER_MP/chef-provisioning-opennebula/bbuczynski-bootstrap-vm_client.rb"
  })
  recipe "bb_syslog_ng::default"
end

one_image "bbuczynski-snap-2-img" do
  machine_id "bbuczynski-bootstrap-vm"
  disk_id "bbuczynski-bootstrap-img"
  action :snapshot
end

machine "bbuczynski-back-1-vm" do
  from_image "bbuczynski-snap-1-img"
  action :ready
end

one_image "bbuczynski-snap-1-img" do
 machine_id 'bbuczynski-back-1-vm'
 action :attach
end

machine "bbuczynski-back-1-vm" do
  files ({
    "/etc/chef/client.rb" => "/home/bbuczynski/PROJECT_FILER_MP/chef-provisioning-opennebula/bbuczynski-back-1-vm_client.rb"
  })
  recipe "bb_syslog_ng::default"
  action :converge
end

machine "bbuczynski-back-2-vm" do
  from_image "bbuczynski-snap-2-img"
  action :ready
end

one_image "bbuczynski-snap-2-img" do
 machine_id 'bbuczynski-back-2-vm'
 action :attach
end

machine "bbuczynski-back-2-vm" do
  files ({
    "/etc/chef/client.rb" => "/home/bbuczynski/PROJECT_FILER_MP/chef-provisioning-opennebula/bbuczynski-back-2-vm_client.rb"
  })
  recipe "bb_syslog_ng::default"
  action :converge
end

one_template "bbuczynski-test-tpl" do
  count 2
#  instances 'bbuczynski-tpl-1-vm'
  action :instantiate
end

machine "bbuczynski-bootstrap-vm" do
  action :destroy
end

one_image "bbuczynski-bootstrap-img" do
  action :destroy
end