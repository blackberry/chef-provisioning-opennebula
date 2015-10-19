# Changelog

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