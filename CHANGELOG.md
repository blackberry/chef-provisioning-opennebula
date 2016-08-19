# Changelog
## 0.4.7 (8/5/2016)
- Added debug info when server_version.rb fails to load 'opennebula' gem, due to bad environment settings
- Added retries to allocate_machine in case ONE has issues and :bootstrap_options are not specified
- Removed default CONTEXT['USER_DATA'] attributes for cloud-init

## 0.4.6 (5/3/2016)
- Added begin/rescue around convergence_strategy deletion in destroy_machine method to avoid failures
  when the client/node objects are not present
- Fixed rubocop errors

## 0.4.5 (4/28/2016)
- Added OneFlow resources (see README): one_flow_template, one_flow_service
- Added RSpec tests for OneFlow
- Fixed RSpec tests for newest chef-client 12.9.38
- Fixed bug regarding destroying machines when machine_spec.reference is nil
- Permitted driver profile switching
- Added backwards compatibility for managing machines provisioned with gem versions prior to v0.3.3
- Added ability to automatically choose the correct opennebula gem version depending on server version

## 0.4.4 (2/29/2016)
- Rewrote RSpec test suite
- Improved chef-run error detection algorithm
- RSpec test results are now organized by datetime and the path of the test recipe
- RSpec now uses `spec/config.rb` rather than environment variables
- Test values, such as disk images, are no longer hardcoded, but are in `config.rb`
- Tests for idempotency are now taken into account
- Expected output for `converge_test_recipe` can now be specified in regex
- Cleanup recipe has been split into multiple deletion tests
- Cleanup is now run before and after the test suite runs
- Fixed a bug introduced in 0.4.3 which failed to create proper VM template if the primitive values were non-string

## 0.4.3 (2/12/2016)
- Fixed get_pool method to process symbols correctly
- Update driver and resources to use new get_pool method
- Add 4.14 support
- Deprecate :enforce_chef_fqdn
- Added template support for embedded quotation marks
- Added ssh_gateway support
- Add :vm_name option to rename VM in OpenNebula UI

## 0.4.1 (8/12/2015)
- Fixed one_vnet_lease :hold action logic.

## 0.4.0 (7/12/2015)
- Added http_port to one_image resource so that port other than 8066 (default) can be used to upload images.
- Fixed error message in one_image resource
- Removed :credentials and :secret_file support as driver options.  It uses profiles now.
- Fixed ssh timeout.  Now the :timeout will be applied to each ssh command and overall timeout to establish
  a ssh session is 5 min.
- one_image now takes 'download_url' as an optional attribute.  'image_file' still takes precedence over 
  'download_url'.  If 'download_url' is specified then that location is used for image and it will not try 
  to start HTTP server locally.
- Changed default port for HTTP server in one_image to be 8066 instead of previously used port 80.  This is to
  avoid collision with existing web servers running on the host.
- Added :mode attribute to one_image, one_template and one_vnet resources.
- Added bootstrap_options[:mode] so that machines can be created with different permissions

## 0.3.4 (10/29/2015)
- Yanked version 0.3.3 from rubygems due to internal homepage link in gemspec
- Need to release version 0.3.4 to reupload to rubygems.org

## 0.3.3 (10/24/2015)
- Changed driver_url to include profiles.  Without profiles machine_file was unable to recreate the driver
  and subsequently failed. The new driver_url format is:
  opennebula:<endpoint_url>:<profile>
  where profile is stored in ~/.one/one_config or ENV['ONE_CONFIG'] or /var/lib/one/.one/one_config file
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
  now this behavior can be changed to call vm.shutdown by specifying :bootstrap_options[:is_shutdown] = true
- Added optional bootstrap_option flag [:unique_name] for validation of unique machine names in OpenNebula
- Removed :instantiate from one_template resource, because it is a duplicate or 'machine :template'
- Fixed warnings in providers regarding resource_names
- Removed support for :ssh_execute_options => { :prefix => 'sudo '} in favour of :sudo => true
- Added license headers
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

- Added upload/download functionality to one_image

## 0.1.0 (4/30/2015)

- Initial submission of chef-provisioning-opennebula gem
