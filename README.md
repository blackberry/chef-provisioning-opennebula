chef-provisioning-opennebula
============================

This is the implementation of the OpenNebula driver for chef-provisioning.  It also comes with additional chef resources to manage OpenNebula:

* Template (one_template)
* Image (one_image)
* VNET (one_vnet)
* Lease (one_vnet_lease)

Setup
-----
In order to use this driver with chef-provisioning the driver URL needs to be specified via environment variable or ```with_driver``` directive.

Starting in version 0.3.3 the driver URL has the following format:

```ruby
opennebula:<endpoint_url>:<profile>
```

Example:

```ruby
with_driver "opennebula:http://1.2.3.4:443/api:boggi"
```

Where ```boggi``` profile is stored the profile file.  The file will be searched in the following order:
1. ```ENV['ONE_CONFIG']```
2. ```"#{ENV['HOME']}/.one/one_config"```
3. ```/var/lib/one/.one/one_config```

A sample one_config file would look like this:

```json
"boggi": {
  "credentials": "boggi:my_token",
  "options": {
    "timeout": 2,
    "sync": true,
    "http_proxy": "http://my.proxy.com"
  }
},
"testuser": {
  "credentials": "testuser:test_token"
}
```

In context of OpenNebula ```machine``` resource will take the following additional options:

```ruby
machine_options {
	:bootstrap_options => {
		:template => Hash defining the VM template,
		:template_file => String location of the VM template file,
		:template_name => String name of the OpenNebula template to use
		:template_id => Integer id of the OpenNebula template to use
		:template_options => Hash values to be merged with VM template
		:is_shutdown => [TrueClass, FalseClass] call vm.shutodwn instead of vm.stop during :stop action
		:shutdown_hard => [TrueClass, FalseClass] flag indicating hard or soft shutdown
    :mode => String octed to set permissions to the machine
	},
	:sudo => true,
	:ssh_username => 'local',
	:ssh_gateway => 'gary@myproxy.net',
	:ssh_options => {
	  Hash containing SSH options as specified by net-ssh gem
	  please see https://github.com/net-ssh/net-ssh for all options
	  Example options:
	  :paranoid => false,
	  :auth_methods => ['publickey'],
	  :keys => [ File.open(File.expand_path('~/.ssh/id_rsa_new')).read ]
	  :keys_only => false,
	  :forward_agent => true,
	  :proxy => 'ssh myproxy.net nc %h %p',
	  :use_agent => true,
	  :user_known_hosts_file => '/dev/null'
	}
  :vm_name => [Symbol, String] Change how the machine shows up in OpenNebula UI and CLI tools.
			       Use :short to rename the machine to the short hostname.
			       Use a string to rename the machine to an arbitrary name.
			       Note this does not change the hostname of the machine, it
			       simply renames the VM in OpenNebula.
  :connection_timeout => [Integer] max wait time to establish connection
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
  :mode => String octet to set permissions
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

## one_image

This resource will manage images within OpenNebula.  

### Attributes

```ruby
  :name => String name of the image to be created or to be used
  :size => Integer size of the image to allocate in MB
  :datastore_id => Integer id of the datastore in OpenNebula to use 
  :type => ['OS', 'CDROM', 'DATABLOCK', 'KERNEL', 'RAMDISK', 'CONTEXT'] type of the image to create
  :description => String description of the image
  :fs_type => String type of the filesystem to create
  :img_driver => String driver type
  :prefix => String prefix
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
  :mode => String octet to set permissions
  :http_port => Integer port number to start local HTTP server at, for :image_file uploads. Default: 8066
```

### Actions

```ruby
  actions :allocate, :create, :destroy, :attach, :snapshot, :upload, :download
  default_action :create
```

```ruby
Default attribute values ONLY for image :create and :allocate actions
          :type = 'OS' 
          :fs_type = 'ext2'
          :img_driver = 'qcow2'
          :prefix = 'vd'
          :persistent = false
```

### Examples

#### 1. Create a datablock image with size 10Gb. 

```ruby
one_image "bootstrap-img" do
  type "DATABLOCK"
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

#### 3. Attach a datablock image 'bootstrap-img' to a VM (test-vm) and attach it as 'vde' target.  'target' is optional.

```ruby
one_image "bootstrap-img" do
  machine_id 'test-vm'
  target 'vde'
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

#### 6. Upload a local qcow2 image file to OpenNebula, starting HTTP server on port 4567

```ruby
one_image "upload-img" do
  datastore_id 103
  image_file "/local/path/to/qcow/image/file"
  img_driver "qcow2"
  type "OS"
  http_port 4567
  description "This is my cool qcow image"
  action :upload
end
```

#### 7. Upload a qcow2 image file residing on a different host to OpenNebula

```ruby
one_image "upload-img" do
  datastore_id 103
  download_url "http://my.image.host/path/to/qcow/image/file"
  action :upload
end
```

#### 8. Download a 'boggi-test-img' and store it in /home/local/my-image.qcow2.  Download URL is read from ENV[ONE_DOWNLOAD] variable. It will be stored locally in Chef::Config[:file_cache_path]/boggi-test-img.qcow2.

```ruby
one_image "boggi-test-img" do
  action :download
end
```

#### 9. Download image ID 12345 and store it in /tmp/image.qcow2.

```ruby
one_image "boggi-test-img" do
  download_url "http://my.opennebula.download.endpoint/"
  image_id 12345
  image_file "/tmp/image.qcow2"
  action :download
end
```

## one_vnet

This resource will allow to create and delete OpenNebula vnets.

### Attributes

```ruby
  :name => String name of the vnet
  :vnet_id => Integer ID of the vnet that is modified
  :network => Integer ID of the vnet from which a new vnet will be reserved
  :size => Integer size of the new vnet
  :ar_id => Integer address range identifier
  :mac_ip => String ip or mac address
  :template_file => String local file containing the template of a new vnet
  :cluster_id => Integer cluster in which to create a vnet
  :mode => String octet to set permissions
```

### Actions

```ruby
  actions :create, :delete, :reserve
  default_action :reserve
```

### Examples

#### 1. Reserver vnet 'boggi_vnet' from parent vnet 12345 with default size 1

```ruby
one_vnet "boggi_vnet" do
    network 12345
    action :reserve
end
```

#### 2. Reserver vnet 'boggi_vnet' from parent vnet 12345 with size 100

```ruby
one_vnet "boggi_vnet" do
    network 12345
    size 100
    action :reserve
end
```

#### 3. Create a VNET from template file in cluster 12345.  This requires the template file not to have NAME variable populated.  The resource will add NAME attribute to the template with the value being the name of the resource.

```ruby
one_vnet "boggi_vnet" do
    template_file "/tmp/my_vnet.tpl"
    cluster_id 12345
    action :create
end
```

#### 4. Delete a vnet 'boggi_vnet'.  NOTE!!! The vnet cannot have any leases in order to be deleted.

```ruby
one_vnet "boggi_vnet" do
    action :delete
end
```

#### 5. Delete vnet by its ID number (12345).  NOTE!!! The vnet cannot have any leases in order to be deleted.

```ruby
one_vnet "boggi_vnet" do
    vnet_id 12345
    action :delete
end
```

## one_vnet_lease

This resource will allow to hold and release leases within OpenNebula vnets.

### Attributes

```ruby
  :name => String ip or mac address to hold/release
  :vnet_id => Integer ID of the vnet that is modified
  :ar_id => Integer address range identifier, where to allocate the address
  :mac_ip => String ip or mac address to hold/release, same as :name
```

### Actions

```ruby
  actions :hold, :release
  default_action :hold
```

### Examples

#### 1. Hold a lease on a specific IP (1.2.3.4) in 'boggi_vnet' (6789)

```ruby
one_vnet_lease "1.2.3.4" do
    vnet "boggi_vnet"
    action :hold
end
```

#### 2. Hold a lease on a specific MAC (00:00:00:00:01) in a specific address range of 'boggi_vnet' (6789).  Assuming that vnet 6789 has more than one address range.

```ruby
one_vnet_lease "00:00:00:00:01" do
    vnet "boggi_vnet"
    ar_id 1
    action :hold
end
```

#### 3. Release a lease on a specific IP (1.2.3.4) in 'boggi_vnet' (6789). If the IP is already allocated to a VM, that VM must be deleted first, otherwise it will throw an error.

```ruby
one_vnet_lease "1.2.3.4" do
    vnet "boggi_vnet"
    action :release
end
```

## one_user

This resource will allow to create/delete/update OpenNebula users. Right now it does not have the full functionality as `oneuser`, but it can add key=value pairs to an existing user so that sensitive data could be stored there.

### Attributes

```ruby
  :name => String ip or mac address to hold/release
  :password => String password
  :user_id => Integer user id
  :template_file => String local template file defining a user 
  :template => Hash with key/value pairs that will be added to the user
  :append => Boolean append to template or overwrite
```

### Actions

```ruby
  actions :create, :delete, :update
  default_action :update
```

### Examples

#### 1. Create a new user from template file, assuming the current ONE user has the permission to do so.

```ruby
one_user "boggi" do
    template_file "<local_template_file>"
    action :create
end
```

#### 2. Delete 'boggi' user, assuming the current ONE user has the permission to do so.

```ruby
one_user "boggi" do
    action :delete
end
```

#### 3. Add new key/value pairs to user 'boggi', assuming the current ONE user has the permission to do so.

```ruby
one_user "boggi" do
    template ({"BOGGI" => "MAGIC"})
    action :update
end
```

## Rspec Integration tests

- Create and configure `spec/config.rb` from `spec/config.sample.rb`, be sure to **read the comments**
- Run `bundle exec rspec ./spec/integration/test_all_integration_spec.rb` from your chef-provisioning-opennebula folder

## <a name="development"></a> Development

* Source hosted at [GitHub][repo]
* Report issues/questions/feature requests on [GitHub Issues][issues]

Pull requests are very welcome! Make sure your patches are well tested.
Ideally create a topic branch for every separate change you make. For
example:

1. Fork the repo
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## <a name="authors"></a> Authors

Created by [Bogdan Buczynski](https://github.com/bbuczynski) (<pikus1@gmail.com>)

## <a name="maintainers"></a> Maintainers

Maintained by
  * [Andrew J. Brown](https://github.com/andrewjamesbrown) (<anbrown@blackberry.com>)
  * [Bogdan Buczynski](https://github.com/bbuczynski) (<pikus1@gmail.com>)
  * [Dongyu 'Gary' Zheng](https://github.com/dongyuzheng) (<garydzheng@gmail.com>)
  * [Evgeny Yurchenko](https://github.com/EYurchenko) (<eyurchenko@blackberry.com>)
  * [Phil Oliva](https://github.com/poliva83) (<philoliva8@gmail.com>)

## <a name="license"></a> License

Apache 2.0 (see [LICENSE][license])

[issues]:           https://github.com/blackberry/chef-provisioning-opennebula/issues
[license]:          https://github.com/blackberry/chef-provisioning-opennebula/blob/master/LICENSE
[repo]:             https://github.com/blackberry/chef-provisioning-opennebula
[driver_usage]:     https://github.com/chef/chef-provisioning/blob/master/docs/building_drivers.md#writing-drivers
[chefdk_dl]:        https://downloads.chef.io/chef-dk/
