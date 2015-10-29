# Changelog

## 0.3.3 (10/24/2015)
- Changed driver_url to include profiles.  Without profiles machine_file was unable to recreate the driver
  and subsequently failed. The new driver_url format is:
  opennebula:<endpoint_url>:<profile>
  where profile is stored in ~/.one/one_config or ENV['ONE_CONFIG'] or /var/lig/one/.one/one_config file
- Added check for machine :destroy to verify that the VM is in DONE state.  If not successful after 20 seconds
  it will fail.
- opennebula 4.14 is not backwards compatible so there is a new gem dependency 'opennebula <4.14'.
- TODO: Support for 4.14

## 0.3.2 (10/8/2015)
- Fix rogue property bug

## 0.3.1 (10/5/2015)
- fix bootstrap_options error
- added rubocop test coverage

## 0.3.0 (9/23/2015)
- Added one_user resource
- Added support for machine shutdown.  Before 'machine :stop' would call the stop method on the VM,
  now this behaviour can be changed to call vm.shutdown by specifying :bootstrap_options[:is_shutdown] = true
- Added optional bootstrap_option flag [:unique_name] for validation of unique machine names in OpenNebula
- Removed :instantiate from one_template resource, because it is a duplicate or 'machine :template'
- Fixed warnings in providers regarding resource_names
- Removed support for :ssh_execute_options => { :prefix => 'sudo '} in favour of :sudo => true
- Added licencse headers
- Modified permissions for downloaded qcow images to be 777
- Added error message when :bootstrap_options are not defined
- Added missing :cache attribute to one_image resource


## 0.2.5 (9/10/2015)

- Fixes driver consistency concerns Tyler Ball brought up in [chef-provisioning issue #390](https://github.com/chef/chef-provisioning/issues/390)
- Following machine options are automatically set using these default values unless over written:

```json
:ssh_username => 'local',
	:ssh_options => {
	:keys_only => false,
	:forward_agent => true,
	:use_agent => true,
	:user_known_hosts_file => '/dev/null'
},
:ssh_execute_options => {
:prefix => 'sudo '
}
```

- deprecated machine option :ssh_user, recommend using :ssh_username instead (consistent with aws driver)
- Added ability to set target on :attach action using one_image resource

## 0.2.4 (8/26/2015)

- Added one_vnet and one_vnet_lease resources

## 0.2.2 (7/18/2015)

- Minor fixes

## 0.2.1 (7/11/2015)

- Added upload/downlod functionality to one_image

## 0.1.0 (4/30/2015)

- Initial submission of chef-provisioning-opennebula gem