chef-provisioning-opennebula
============================

This is the implementation of the OpenNebula driver for chef-provisioning.  It also comes with two additional resources:

* Template  (one_template)
* Image (one_image)

Setup
-----
In order to use this driver with chef-provisioning the driver URL needs to be specified via environment variable or ```with_driver``` directive.

The driver URL has the following formats:

```ruby
opennebula:<endpoint_url>
```

The driver also requires credentials to connect to OpenNebula endpoint.  These can be specified via ```driver_options```

```ruby
with_driver "opennebula:http://1.2.3.4/endpoint:port",
  :credentials => "<username>:<text_password>"
```

or

```ruby
with_driver "opennebula:http://1.2.3.4/endpoint:port",
  :secret_file => "<local_path_to_file_with_credentials>"
```

In context of OpenNebula ```machine``` resource will take the following additional options:

```ruby
machine_options {
	:bootstrap_options => {
		:template => Hash defining the VM template,
		:template_file => String location of the VM template file,
		:template_name => String name of the OpenNebula template to use
		:template_id => Integer id of the OpenNebula template to use
	},
	:ssh_user => 'local',
	:ssh_options => {
	  Hash containing SSH options as specified by net-ssh gem
	  please see https://github.com/net-ssh/net-ssh for all options
	  Example options:
	  :paranoid => false,
	  :auth_methods => ['publickey'],
	  :keys => [ File.open(File.expand_path('~/.ssh/id_rsa_new')).read ]
	  :keys_only => false,
	  :forward_agent => true,
	  :use_agent => true,
	  :user_known_hosts_file => '/dev/null'
	},
	:ssh_execute_options => {
	  :prefix => 'sudo '
	}
}
```

Resources
---------

## one_template

This resource will allow to create and delete OpenNebula templates.

### Attributes

```ruby
  :template => Hash defining OpenNebula template
  :template_file => String location of the VM template file
  :count => Integer number of instances to create
  :instances => [String, Array] name(s) for the instances to create
```

### Actions

```ruby
  actions :create, :delete, :instantiate
  default_action :create
```

### Examples

#### 1. Create OpenNebula template from file

```ruby
one_template "my_one_template" do
    template_file "/opt/one/templates/my_template.tpl"
    action :create
end
```

#### 2. Create OpenNebula template from a template definition

```ruby
one_template "my_one_template" do
  template  ({
    "HTTPBASE" => "http://my.server.com",
    "MEMORY" => "4096",
    "CPU" => "2",
    "VCPU" => "2",
    "OS" => {
        "ARCH" => "x86_64"
    },
    "DISK" => {
        "IMAGE" => "Ubuntu-12.04.5-pre-prod-20141216",
        "IMAGE_UNAME" => "my_user",
        "DRIVER" => "qcow2"
    },
    "NIC" => {
      "NETWORK" => "my_network",
      "NETWORK_UNAME" => "my_network_user"
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
          "SSH_PUBLIC_KEY" => "ssh-rsa blahblahblahpublickey root@my_host",
          "FILES" => "$HTTPBASE/01_chef $HTTPBASE/../chef-client.deb"
    }
  })
  action :create
end
```

#### 3. Delete an existing template in OpenNebula

```ruby
one_template "my_one_template" do
    action :delete
end
```

#### 4. Create an OpenNebula template from file and also create 2 VM instances from that template.
The resulting names of the VMs will be ```<template_name>-<one_id>``` where ```one_id``` is an OpenNebula sequence number.

```ruby
one_template "my_one_template" do
	template_file "/opt/one/templates/my_template.tpl"
	count 2
    action [:create, :instantiate]
end
```

#### 5. Create an OpenNebula template from file and also create 2 VM instances from that template with specific names.

```ruby
one_template "my_one_template" do
	template_file "/opt/one/templates/my_template.tpl"
	instances ['boggi-vm-1', 'boggi-vm-2']
    action [:create, :instantiate]
end
```

## one_image

This resource will manage images within OpenNebula.  

### Attributes

```ruby
  :name => String name of the image to be created or to be used
  :size => Integer size of the image to allocate in MB
  :datastore_id => Integer id of the datastore in OpenNebula to use 
  :type => ['OS', 'CDROM', 'DATABLOCK', 'KERNEL', 'RAMDISK', 'CONTEXT'] type of the image to create; default: 'DATABLOCK'
  :description => String description of the image
  :fs_type => String type of the filesystem to create; default: 'ext2'
  :img_driver => String driver type; default: 'qcow2'
  :prefix => String prefix; default: 'vd'
  :persistent => [ TrueClass, FalseClass] flag indicating if the image should be persistent; default: false
  :public => [ TrueClass, FalseClass ] flag indicating if the image is public
  :disk_type => String Image disk type eq. ext3
  :source => String Image source attribute
  :target => String Image target attribute 
  :image_file => String Local path to the qcow image file. Default: Chef::Config[:file_cache_path]
  :image_id => Integer ID of the image to download
  :download_url => String OpenNebula download URL. Default is ENV['ONE_DOWNLOAD']
  :driver => String Image driver eq. 'qcow2'
  :machine_id => [String, Integer] id of the machine (VM) for disk attach
  :disk_id => [String, Integer] id or name of the disk to attach/snapshot
```

### Actions

```ruby
  actions :allocate, :create, :destroy, :attach, :snapshot, :upload, :download
  default_action :create
```

### Examples

#### 1. Create a datablock image with size 10Gb

```ruby
one_image "bootstrap-img" do
  size 10240
  datastore_id 103
  action :create
end
```

#### 2. Delete a datablock image with name 'bootstrap-img'

```ruby
one_image "bootstrap-img" do
  action :destroy
end
```

#### 3. Attach a datablock image 'bootstrap-img' to a VM (test-vm)

```ruby
one_image "bootstrap-img" do
  machine_id 'test-vm'
  action :attach
end
```

#### 4. Take a persistent snapshot of disk 1 on VM (test-vm) and save it as 'snapshot-img'

```ruby
one_image "snapshot-img" do
  machine_id "test-vm"
  disk_id 1
  persistent true
  action :snapshot
end
```

#### 5. Take a persistent snapshot of disk 'bootstrap-img' on VM (test-vm) and save it as 'snapshot-img

```ruby
one_image "snapshot-img" do
  machine_id "test-vm"
  disk_id "bootstrap-img"
  persistent true
  action :snapshot
end
```

#### 6. Upload a local qcow2 image file to OpenNebula

```ruby
one_image "snapshot-img" do
  datastore_id "test-vm"
  image_file "/local/path/to/qcow/image/file"
  img_driver "qcow2"
  type "OS"
  description "This is my cool qcow image"
  action :upload
end
```

#### 7. Download a 'boggi-test-img' and store it in /home/local/my-image.qcow2.  Download URL read from ENV[ONE_DOWNLOAD] variable. It will be stored locally in Chef::Config[:file_cache_path]/boggi-test-img.qcow2.

```ruby
one_image "boggi-test-img" do
  action :download
end
```

#### 8. Download image ID 12345 and store it in /tmp/image.qcow2.

```ruby
one_image "boggi-test-img" do
  download_url "http://my.opennebula.download.endpoint/"
  image_id 12345
  image_file "/tmp/image.qcow2"
  action :download
end
```

## Rspec Integration tests

Run 'bundle exec rspec ./spec/integration/test_all_integration_spec.rb' in your chef-provisioning-opennebula folder 

Set the following environment variables according to your needs:

```ruby
ENV['HOME']           - your home directory
ENV['ONE_XMLRPC']     - this is the OpenNebula endpoint url
ENV['ONE_AUTH']       - the path to your one_auth file 
ENV['ONE_HTTPBASE']   - the base URL from which files are downloaded eg. chef-client.deb, init.sh, service.gz etc.
ENV['CHEF_REPO_PATH'] - the path to your local chef repo
```
