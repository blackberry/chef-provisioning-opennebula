#######################################################
## This is the config file used for the RSpec tests. ##
## Feel free to modify any variables to your needs.  ##
#######################################################

# your driver url, opennebula:<endpoint_url>:<profile>
DRIVER_URL = 'opennebula:http://api.opennebula/api:oneuser'

# set this to nil if you do not want to test OneFlow
ONE_FLOW_URL = 'http://api.oneflow:2474'

# the path to your local chef repo, an empty folder would work, if the folder does not exist, one will be automatically created
CHEF_REPO_PATH = "#{ENV['HOME']}/test-repo"

# required for recipes involving allocating datablocks
DATASTORE_ID = 123

# required for recipes involving allocating vnets
VNET_ID = 321

VM_TEMPLATE = {
  # the base URL from which files are downloaded eg. chef-client.deb, init.sh, service.gz etc.
  'HTTPBASE' => 'http://cli.opennebula/~oneuser',
  # it is highly recommended to keep resources low for these tests
  'MEMORY' => '1024',
  'CPU' => '1',
  'VCPU' => '1',
  'OS' => {
    'ARCH' => 'x86_64'
  },
  'DISK' => {
    'IMAGE' => 'Ubuntu-16.04-2017.10.10-b46',
    'IMAGE_UNAME' => 'oneuser',
    'DRIVER' => 'qcow2'
  },
  'NIC' => {
    'NETWORK' => 'oneadmin-public-vnet',
    'NETWORK_UNAME' => 'oneadmin'
  },
  'GRAPHICS' => {
    'LISTEN' => '0.0.0.0',
    'TYPE' => 'vnc'
  },
  'CONTEXT' => {
    'NETWORK' => 'YES',
    'HOSTNAME' => '$NAME',
    'SSH_USERNAME' => 'local',
    'SSH_PUBLIC_KEY' => File.read("#{ENV['HOME']}/.ssh/id_rsa.pub").strip,
    'INSTALL_CHEF_CLIENT_COMMAND' => 'dpkg -E -i /mnt/chef_12.21.4-1_amd64.deb',
    'FILES' => '$HTTPBASE/context/init.sh $HTTPBASE/chef_12.21.4-1_amd64.deb'
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
  :convergence_options => {
    :chef_version => '12.21.4'
  },
  :sudo => true,
  :cached_installer => true
}

# download URL for JSON template file
JSON_TEMPLATE_URL = 'http://cli.opennebula/~oneuser/RSpec-flow-http-template.json'
