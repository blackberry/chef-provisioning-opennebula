#######################################################
## This is the config file used for the RSpec tests. ##
## Feel free to modify any variables to your needs.  ##
#######################################################

# your driver url, opennebula:<endpoint_url>:<profile>
DRIVER_URL = 'opennebula:http://1.2.3.4:443/api:boggi'

# test for profile moving, set nil to skip
DRIVER_URL_2 = 'opennebula:http://1.2.3.4:443/api:gary'

# set this to nil if you do not want to test OneFlow
ONE_FLOW_URL = 'http://gary.1.2.3.4:9876'

# the path to your local chef repo, an empty folder would work, if the folder does not exist, one will be automatically created
CHEF_REPO_PATH = '/home/gary/test-repo'

# required for recipes involving allocating datablocks
DATASTORE_ID = 103

# required for recipes involving allocating vnets
VNET_ID = 394

VM_TEMPLATE = {
  # the base URL from which files are downloaded eg. chef-client.deb, init.sh, service.gz etc.
  'HTTPBASE' => 'http://my.server.com',
  # it is highly recommended to keep resources low for these tests
  'MEMORY' => '256',
  'CPU' => '1',
  'VCPU' => '1',
  'OS' => {
    'ARCH' => 'x86_64'
  },
  'DISK' => {
    'IMAGE' => 'Ubuntu-14.04.1-pre-prod-201411201',
    'IMAGE_UNAME' => 'my_user',
    'DRIVER' => 'qcow2'
  },
  'NIC' => {
    'NETWORK' => 'my_network',
    'NETWORK_UNAME' => 'my_network_user'
  },
  'GRAPHICS' => {
    'LISTEN' => '0.0.0.0',
    'TYPE' => 'vnc'
  },
  'CONTEXT' => {
    'NETWORK' => 'YES',
    'HOSTNAME' => '$NAME',
    'INSTALL_CHEF_CLIENT_COMMAND' => 'dpkg -E -i /mnt/chef-client.deb',
    'SSH_USERNAME' => 'local',
    'SSH_PUBLIC_KEY' => File.read("#{ENV['HOME']}/.ssh/id_rsa.pub").strip,
    'FILES' => '$HTTPBASE/01_chef $HTTPBASE/../chef-client.deb'
  }
}

MACHINE_OPTIONS = {
  :ssh_username => 'local',
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
}
