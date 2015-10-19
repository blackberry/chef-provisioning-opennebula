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

require 'cheffish/rspec/chef_run_support'
require 'cheffish/rspec/matchers'
require 'chef/provisioning/opennebula_driver'

def chef_run(recipe)
  chef_client = Mixlib::ShellOut.new("bundle exec chef-client -z ./spec/recipes/driver_options_spec.rb ./spec/recipes/#{recipe} --force-formatter", shellout_options({:timeout => 900}))
  chef_client.run_command
  chef_client.stdout
end

def shellout_options(options = {})
  default_options = { :live_stream => STDOUT }
  default_options.merge(options)
end

def delete_all
  chef_run("delete_all_spec.rb")
end

# checks for runtime / idempotency-related errors in the stdout
def check_for_error(recipe, stdout, expected = nil, error = nil)
  if stdout.include?("RuntimeError:")
    return (stdout.split("RuntimeError:").last).split("\n").first
  elsif stdout.include?("NoMethodError:")
    return (stdout.split("NoMethodError:").last).split("\n").first
  end
  return nil if expected and stdout.include?(expected)
  if recipe == "delete_all_spec.rb"
    error_message = "A resource failed to delete successfully." if error and stdout.include?(error)
  else
    error_message = error if error and stdout.include?(error)
  end
  error_message
end

RSpec::Matchers.define :"converge_test_recipe" do |recipe, expected, error|
  match do |recipe|
    stdout = chef_run(recipe)
    # logs each chef run
    File.open("./test-results/#{File.basename(recipe, '.*')}_stdout.log", "w+") { |file| file.write(stdout) }    
    @error_message = check_for_error(recipe, stdout, expected, error)
    # copies the stacktrace for tests that have failed
    File.open("./test-results/#{File.basename(recipe, '.*')}_stacktrace.out", "w+") { |file| file.write(File.read("#{ENV['HOME']}/.chef/local-mode-cache/cache/chef-stacktrace.out")) } if @error_message
    failed = true if @error_message
    !failed
  end
  failure_message do
    @error_message
  end
end