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
    class OneTemplate < Chef::Provider::LWRPBase
      use_inline_resources

      provides :one_template

      attr_reader :uname
      attr_reader :equal_template
      attr_reader :equal_mode
      attr_reader :current_id

      def whyrun_supported?
        true
      end

      def load_current_resource
        driver = self.driver
        @uname = uname
        @current_resource = Chef::Resource::OneTemplate.new(new_resource.name,
                                                            run_context)
        @current_resource.name(new_resource.name)
        template = driver.one.get_resource(:template,
                                           :name => @current_resource.name,
                                           :uname => @uname)
        @current_resource.exists = !template.nil?

        return unless @current_resource.exists

        new_resource_template = if @new_resource.template_file.nil?
                                  convert_types(@new_resource.template)
                                else
                                  driver.one.template_from_file(@new_resource.template_file)
                                end

        @current_id = template.to_hash['VMTEMPLATE']['ID'].to_i
        @current_resource.template(template.to_hash['VMTEMPLATE']['TEMPLATE'])
        @current_resource.mode(get_mode(template))
        @equal_template = @current_resource.template == new_resource_template
        @equal_mode = @current_resource.mode == new_resource.mode
        @current_resource.equal = @equal_template && @equal_mode
      end

      action :create do
        template_str = create_template

        unless @current_resource.equal
          if @current_resource.exists
            unless @equal_template
              converge_by "update template content on '#{new_resource.name}'" do
                driver.one.update_template(@current_id, template_str)
              end
            end
            unless @equal_mode
              converge_by('update template permissions on ' \
                "'#{new_resource.name}' to #{new_resource.mode}") do
                template = driver.one.get_resource(:template,
                                                   :name => @current_resource.name,
                                                   :uname => @uname)
                driver.one.chmod_resource(template, new_resource.mode)
              end
            end
          else
            converge_by("create template '#{new_resource.name}'") do
              create_one_template(template_str)
            end
          end
          new_resource.updated_by_last_action(true)
        end
      end

      action :create_if_missing do
        template_str = create_template

        unless @current_resource.exists
          converge_by("create template '#{new_resource.name}'") do
            create_one_template(template_str)
          end
          new_resource.updated_by_last_action(true)
        end
      end

      action :delete do
        converge_by("delete template '#{new_resource.name}'") do
          template = driver.one.get_resource(:template,
                                             :name => @current_resource.name,
                                             :uname => @uname)
          template.delete
          new_resource.updated_by_last_action(true)
        end if @current_resource.exists
      end

      protected

      def driver
        current_driver = begin
          if new_resource.driver
            run_context.chef_provisioning.driver_for(new_resource.driver)
          elsif run_context.chef_provisioning.current_driver
            run_context.chef_provisioning.driver_for(run_context.chef_provisioning.current_driver)
          end
        end
        fail "Driver not specified for one_template  #{new_resource.name}" unless current_driver
        current_driver
      end

      def create_one_template(template_str)
        unless new_resource.template.key?('NAME')
          template_str << "\n" << 'NAME="' << new_resource.name << '"'
        end
        driver.one.allocate_template(template_str)
        template = driver.one.get_resource(:template,
                                           :name => @current_resource.name,
                                           :uname => @uname)
        driver.one.chmod_resource(template, new_resource.mode)
      end

      def create_template
        if new_resource.template_file && new_resource.template.size > 0
          fail("Attributes 'template_file' and 'template' are mutually " \
               'exclusive.')
        elsif new_resource.template_file
          ::File.read(new_resource.template_file)
        elsif new_resource.template.size > 0
          driver.one.create_template(new_resource.template)
        else
          fail("Missing attribute 'template_file' or 'template' in " \
               'resource block.')
        end
      end

      def convert_types(hash)
        tpl_str = driver.one.create_template(hash)
        t_hash = nil
        doc = OpenNebula::CustomObject.new(OpenNebula::CustomObject.build_xml, driver.one.client)
        unless OpenNebula.is_error?(doc)
          rc = doc.allocate(tpl_str)
          fail "Failed to allocate OpenNebula document: #{rc.message}" if OpenNebula.is_error?(rc)
          doc.info!
          t_hash = doc.to_hash['DOCUMENT']['TEMPLATE']
          doc.delete
        end
        t_hash
      end

      def get_mode(template)
        perms = template.to_hash['VMTEMPLATE']['PERMISSIONS']
        mode = 0
        %w(OWNER_U OWNER_M OWNER_A GROUP_U GROUP_M GROUP_A
           OTHER_U OTHER_M OTHER_A).each do |m|
          mode += perms[m].to_i
          mode = mode << 1
        end
        mode = mode >> 1
        mode.to_s(8)
      end

      def uname
        xml = OpenNebula::User.build_xml(OpenNebula::User::SELF)
        my_user = OpenNebula::User.new(xml, driver.one.client)
        my_user.info!
        my_user.to_hash['USER']['NAME']
      end
    end
  end
end
