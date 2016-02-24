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

require 'cheffish/rspec/chef_run_support'
require 'cheffish/rspec/matchers'
require 'chef/provisioning/opennebula_driver'
require 'fileutils'

def chef_run(recipe)
  chef_client = Mixlib::ShellOut.new(
    "bundle exec chef-client -z ./spec/recipes/driver_options_spec.rb ./spec/recipes/#{recipe} --force-formatter",
    shellout_options(:timeout => 900)
  )
  chef_client.run_command
  chef_client.stdout
end

def shellout_options(options = {})
  { :live_stream => STDOUT }.merge(options)
end

def format_error(msg)
  "================================================================================\n#{msg}\n================================================================================"
end

# gets runtime / idempotency-related errors from stdout
def get_error(stdout, expected = nil, error = nil)
  unless error.nil?
    case error
    when Regexp
      return "stdout matched:\n#{error}" if stdout =~ error
    when String
      return "stdout included:\n#{error}" if stdout.include?(error)
    end
  end

  if stdout.include?('RuntimeError: ')
    return "RuntimeError\n" + (stdout.split('RuntimeError: ').last).split("\n").first
  elsif stdout.include?('NoMethodError: ')
    return "NoMethodError\n" + (stdout.split('NoMethodError: ').last).split("\n").first
  elsif stdout.include?('ERROR: ')
    return "ERROR\n" + (stdout.split('ERROR: ').last).split("\n").first
  elsif stdout.include?('FATAL: ')
    return "FATAL\nAn unknown fatal error has occurred."
  end

  return nil if expected.nil?

  case expected
  when Symbol
    fail "The only symbol supported for 'expected' is :idempotent, you passed :#{expected}" unless expected == :idempotent
    return 'Chef run did not idempotently skip when it should have.' unless stdout.include?('(up to date)')
  when Regexp
    return "Chef run idempotently skipped when it should not have.\nIf you intended for it to skip, pass in :idempotent as 'expected' instead." if stdout.include?('(up to date)')
    return "No match in stdout for:\n#{expected}" unless stdout =~ expected
  when String
    return "Chef run idempotently skipped when it should not have.\nIf you intended for it to skip, pass in :idempotent as 'expected' instead." if stdout.include?('(up to date)')
    return "stdout did not include:\n#{expected}" unless stdout.include?(expected)
  end
end

RSpec::Matchers.define :converge_test_recipe do |recipe = nil, expected = :idempotent, error = nil|
  fail 'All tests require a recipe.' if recipe.nil?
  match do
    stdout = chef_run(recipe)
    # logs each chef run
    dir = RSpec.configuration.log_dir + '/' + File.dirname(recipe)
    FileUtils.mkdir_p(dir)
    log_basename = expected == :idempotent ? File.basename(recipe, '.*') + '__i' : File.basename(recipe, '.*')
    File.open("./#{dir}/#{log_basename}_stdout.log", 'w+') { |file| file.write(stdout) }
    @error_message = get_error(stdout, expected, error)
    @error_message = format_error(@error_message) unless @error_message.nil?
    # copies the stacktrace for tests that have failed
    FileUtils.cp(
      "#{ENV['HOME']}/.chef/local-mode-cache/cache/chef-stacktrace.out",
      "./#{dir}/#{log_basename}_stacktrace.out"
    ) unless @error_message.nil?
    @error_message.nil?
  end
  failure_message do
    @error_message
  end
end
