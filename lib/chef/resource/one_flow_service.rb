# Copyright 2016, BlackBerry Limited
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

require 'chef/provider/one_flow_service'

#
# Implementation of Resource class.
#
class Chef
  #
  # Implementation of Resource class.
  #
  class Resource
    #
    # Implementation of Resource class.
    #
    class OneFlowService < Chef::Resource::LWRPBase
      resource_name :one_flow_service

      attribute :name, :kind_of => String, :name_attribute => true
      attribute :template, :kind_of => [Fixnum, String], :default => nil
      attribute :template_options, :kind_of => Hash, :default => {}
      attribute :mode, :regex => [/^[0-7]{3}$/], :default => '600'
      attribute :role, :regex => [/^\w+$/], :default => nil
      attribute :cardinality, :kind_of => Fixnum, :default => -1
      attribute :period, :kind_of => Fixnum, :default => nil
      attribute :number, :kind_of => Fixnum, :default => nil
      attribute :force_scale, :kind_of => [TrueClass, FalseClass], :default => false
      attribute :override_failsafe, :kind_of => [TrueClass, FalseClass], :default => false

      attribute :driver
      attribute :flow_url

      attr_accessor :exists, :equal, :template_equal, :mode_equal, :in_running_state

      actions :instantiate, :recover, :delete, :shutdown, :scale,
              :shutdown_hard, :undeploy, :undeploy_hard, :hold,
              :release, :stop, :suspend, :resume, :boot,
              :delete_recreate, :reboot, :reboot_hard, :poweroff,
              :poweroff_hard, :snapshot_create

      default_action :instantiate

      def initialize(*args)
        super
        @driver = run_context.chef_provisioning.current_driver
      end
    end
  end
end
