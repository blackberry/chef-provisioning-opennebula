# Copyright 2015, BlackBerry, Inc.
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

require 'chef/provisioning/opennebula_driver'

endpoint = "#{ENV['ONE_XMLRPC']}".dup
home = "#{ENV['HOME']}".dup
auth = File.read(ENV['ONE_AUTH'])
httpbase = "#{ENV['ONE_HTTPBASE']}".dup
chef_repo_path = "#{ENV['CHEF_REPO_PATH']}".dup

with_driver "opennebula:#{endpoint}",
   :credentials => "#{auth}"

with_machine_options :bootstrap_options => {
  :template => {
      "HTTPBASE" => "#{httpbase}",
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
        "SSH_PUBLIC_KEY" => File.read("#{home}/.ssh/id_rsa.pub").strip,
        "FILES" => "$HTTPBASE/01_chef $HTTPBASE/../chef-client.deb"
      }
    }
  },
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
  
with_chef_local_server :chef_repo_path => "#{chef_repo_path}"