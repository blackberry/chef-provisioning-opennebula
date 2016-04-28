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

require 'rest-client'
require 'json'

#
# Implementation of Provider class.
#
class Chef
  #
  # Implementation of Provider class.
  #
  class Provider
    #
    # Implementation of Provider class.
    #
    class OneFlowTemplate < Chef::Provider::LWRPBase
      use_inline_resources

      provides :one_flow_template

      def initialize(*args)
        super
        if !@new_resource.flow_url.nil?
          flow_url = @new_resource.flow_url
        elsif !run_context.chef_provisioning.flow_url.nil?
          flow_url = run_context.chef_provisioning.flow_url
        elsif !ENV['ONE_FLOW_URL'].nil?
          flow_url = ENV['ONE_FLOW_URL']
        else
          fail 'OneFlow API URL must be specified.'
        end
        @flow_lib = Chef::Provisioning::OpenNebulaDriver::FlowLib.new(flow_url, driver.one.client.one_auth)
      end

      def whyrun_supported?
        true
      end

      def load_current_resource
        @current_resource = Chef::Resource::OneFlowTemplate.new(@new_resource.name, run_context)

        template_name = @new_resource.name

        unless @new_resource.template.nil?
          tpl = load_template_hash
          if tpl.nil?
            @current_resource.exists = false
            return
          end
          tpl = @flow_lib.merge_template(tpl, @new_resource.template_options, true, false)
          template_name = tpl[:name] if tpl.key?(:name)
        end

        template_id = @flow_lib.get_unique_template_id(template_name, true)

        @current_resource.exists = !template_id.nil?
        return unless @current_resource.exists

        @current_resource.template(@flow_lib.get_template(template_id))
        @current_resource.mode(@flow_lib.get_template_permissions(template_id))

        @current_resource.template_equal = @new_resource.template.nil? ? true : @flow_lib.hash_eq?(
          @current_resource.template,
          @flow_lib.normalize_template(@new_resource.name, driver, @flow_lib.merge_template(@current_resource.template, tpl), true)
        )
        @current_resource.mode_equal = @current_resource.mode == @new_resource.mode
        @current_resource.equal = @current_resource.template_equal && @current_resource.mode_equal
      end

      def load_template_hash
        template = {}
        case @new_resource.template
        when Hash
          template = @new_resource.template
        when Fixnum
          template = @flow_lib.get_template(@new_resource.template)
        when String
          case @new_resource.template
          when %r{^file://(.*)$}
            template = JSON.parse(::File.read(Regexp.last_match[1]), :symbolize_names => true)
          when %r{^(?:(\w+)(?::(.*?))?@)?(https?://.*)$}
            response = RestClient::Request.execute(
              method: :get,
              url: Regexp.last_match[3],
              user: Regexp.last_match[1],
              password: Regexp.last_match[2]
            )
            template = JSON.parse(response, :symbolize_names => true)
          else
            tid = @flow_lib.get_unique_template_id(@new_resource.template)
            template = @flow_lib.get_template(tid)
          end
        end
        template
      end

      action :create do
        fail 'Cannot specify template_options without a template' if !@current_resource.template_options.empty? && @current_resource.template_options.nil?

        template_name = @new_resource.name

        unless @new_resource.template.nil?
          template = load_template_hash

          if @new_resource.template_options.key?(:name)
            template_name = @new_resource.template_options[:name]
          elsif template.key?(:name)
            template_name = template[:name]
          end
        end

        if @current_resource.exists
          unless @current_resource.equal
            converge_by "updated template '#{template_name}'" do
              template_id = @flow_lib.get_unique_template_id(template_name)
              unless @new_resource.template.nil? && @current_resource.template_equal
                template = @flow_lib.normalize_template(
                  @new_resource.name,
                  driver,
                  @flow_lib.merge_template(template, @new_resource.template_options, true, false),
                  true,
                  true
                )
                template = @flow_lib.normalize_template(@new_resource.name, driver, @flow_lib.merge_template(@current_resource.template, template))
                @flow_lib.update_template(template_name, template)
              end
              unless @current_resource.mode_equal
                @flow_lib.chmod_template(template_id, @new_resource.mode)
              end
              @new_resource.updated_by_last_action(true)
            end
          end
        else
          fail 'Cannot create template without template attribute' if @new_resource.template.nil?
          converge_by "created template '#{template_name}'" do
            template = @flow_lib.normalize_template(@new_resource.name, driver, @flow_lib.merge_template(template, @new_resource.template_options, true))
            @flow_lib.create_template(template)
            template_id = @flow_lib.get_unique_template_id(template_name)
            @flow_lib.chmod_template(template_id, @new_resource.mode)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      action :delete do
        if @current_resource.exists
          template_id = @flow_lib.get_unique_template_id(@new_resource.name, true)
          converge_by "deleted template '#{@new_resource.name}'" do
            @flow_lib.delete_template(template_id)
            @new_resource.updated_by_last_action(true)
          end
        end
      end

      protected

      def driver
        @new_resource.driver.nil? ? run_context.chef_provisioning.current_driver : run_context.chef_provisioning.driver_for(@new_resource.driver)
      end
    end
  end
end
