# Copyright 2016, BlackBerry, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'chef/provisioning/opennebula_driver'
require 'fileutils'
require "#{File.dirname(__FILE__)}/../config.rb"

FileUtils.mkdir_p(CHEF_REPO_PATH.chomp('/'))
with_chef_local_server :chef_repo_path => CHEF_REPO_PATH.chomp('/')
with_driver (ONE_XMLRPC[0, 11] == 'opennebula:' ? ONE_XMLRPC : 'opennebula:' + ONE_XMLRPC).chomp('/')

with_machine_options MACHINE_OPTIONS.merge(
  :bootstrap_options => {
    :template => VM_TEMPLATE
  }
)
