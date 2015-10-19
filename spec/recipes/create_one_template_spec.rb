require 'chef/provisioning/opennebula_driver'

home = "#{ENV['HOME']}".dup
httpbase = "#{ENV['ONE_HTTPBASE']}".dup

one_template "OpenNebula-test-tpl" do
  template  ({
    "HTTPBASE" => "#{httpbase}",
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
          "SSH_PUBLIC_KEY" => File.read("#{home}/.ssh/id_rsa.pub").strip,
          "FILES" => "$HTTPBASE/01_chef $HTTPBASE/../chef-client.deb"
    }
  })
  action :create
end