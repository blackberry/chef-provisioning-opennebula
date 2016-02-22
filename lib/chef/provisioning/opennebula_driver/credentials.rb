# Copyright 2015, BlackBerry, Inc.
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

require 'json'

#
# Implementation of Provider class.
#
class Chef
  #
  # Extending module.
  #
  module Provisioning
    #
    # Extending module.
    #
    module OpenNebulaDriver
      #
      # Implementation of Provider class.
      #
      class Credentials
        def initialize(options = {})
          @credentials = {}
          load_default(options)
          load_profiles
        end

        def default
          fail 'No credentials loaded!  Do you have a ~/.one/one_auth file?' if @credentials.size == 0
          @credentials[ENV['ONE_DEFAULT_PROFILE'] || 'default'] || @credentials.first[1]
        end

        def [](name)
          fail "Profile '#{name}' does not exist" unless @credentials[name]
          @credentials[name]
        end

        def load_default(options = {})
          oneauth_file = ENV['ONE_AUTH'] || File.expand_path('~/.one/one_auth')
          begin
            creds = File.read(oneauth_file).strip
            @credentials['default'] = { :credentials => creds, :options => options }
          end if File.file?(oneauth_file)
        end

        def load_profiles
          file = nil
          if ENV['ONE_CONFIG'] && !ENV['ONE_CONFIG'].empty? && File.file?(ENV['ONE_CONFIG'])
            file = ENV['ONE_CONFIG']
          elsif ENV['HOME'] && File.file?("#{ENV['HOME']}/.one/one_config")
            file = "#{ENV['HOME']}/.one/one_config"
          elsif File.file?("/var/lib/one/.one/one_config")
            file = "/var/lib/one/.one/one_config"
          else
            Chef::Log.info("No ONE_CONFIG file found, will use default profile")
          end
          json = {}
          begin
            content_hash = JSON.parse(File.read(file), :symbolize_names => true)
            content_hash.each { |k, v| json[k.to_s] = v }
          rescue StandardError => e_file
            Chef::Log.warn("Failed to read config file #{file}: #{e_file.message}")
          rescue JSON::ParserError => e_json
            Chef::Log.warn("Failed to parse config file #{file}: #{e_json.message}")
          rescue
            Chef::Log.warn("Failed to read or parse config file #{file}: #{$!}")
          end
          @credentials.merge!(json)
        end

        def load_plain(creds, options = {})
          @credentials['default'] = {
            :credentials => creds,
            :options => options
          } unless creds.nil?
          @credentials
        end

        def load_file(filename, options = {})
          creds = File.read(filename).strip if File.file?(filename)
          @credentials['default'] = {
            :credentials => creds,
            :options => options
          } unless creds.nil?
          @credentials
        end

        def self.method_missing(name, *args, &block)
          singleton.send(name, *args, &block)
        end

        def self.singleton
          @one_credentials ||= Credentials.new
        end
      end
    end
  end
end
