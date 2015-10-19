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
  
one_template "OpenNebula-test-tpl" do
  action :delete
end

machine "OpenNebula-tpl-1-vm" do
  action :destroy
end

machine "OpenNebula-bootstrap-vm" do
  action :destroy
end

one_image "OpenNebula-bootstrap-img" do
  action :destroy
end

machine "OpenNebula-back-1-vm" do
  action :destroy
end

machine "OpenNebula-back-2-vm" do
  action :destroy
end

one_image "OpenNebula-snap-1-img" do
  action :destroy
end

one_image "OpenNebula-snap-2-img" do
  action :destroy
end