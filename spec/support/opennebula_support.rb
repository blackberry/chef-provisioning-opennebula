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

require 'cheffish/rspec/chef_run_support'
require 'cheffish/rspec/matchers'
require 'chef/provisioning/opennebula_driver'
require 'fileutils'

def chef_run(recipe, append_path = true)
  recipe_array = recipe.is_a?(Array) ? recipe : [recipe]
  recipe_array.map! { |r| './spec/recipes/' + r } if append_path
  recipe_array = ['./spec/recipes/common.rb'] + recipe_array
  FileUtils.rm_rf('/tmp/chef-provisioning-opennebula-rspec-recipe.rb')
  File.open('/tmp/chef-provisioning-opennebula-rspec-recipe.rb', 'a') do |file|
    file.puts("require '#{File.dirname(__FILE__)}/../config.rb'")
    recipe_array.each do |recipe_file|
      content = File.read(recipe_file)
      file.puts('')
      file.puts(content)
    end
  end
  chef_client = Mixlib::ShellOut.new(
    'chef-client -z /tmp/chef-provisioning-opennebula-rspec-recipe.rb --force-formatter',
    shellout_options(:timeout => 900)
  )
  chef_client.run_command
  chef_client.stdout
end

def shellout_options(options = {})
  { :live_stream => STDOUT }.merge(options)
end

def format_error(msg)
  "================================================================================\n#{msg}\n================================================================================\n "
end

def get_unique_file(path, basename, rest)
  p = path.chomp('/')
  fn = "#{p}/#{basename}#{rest}"
  return fn unless File.exist?(fn)
  n = 1
  n += 1 while File.exist?("#{p}/#{basename}__#{n}#{rest}")
  "#{p}/#{basename}__#{n}#{rest}"
end

def get_error(stdout, expected, fail_if)
  stacktrace = stdout.match(/FATAL: Stacktrace dumped to (.*?chef-stacktrace\.out)/)
  stacktrace = stacktrace ? stacktrace[1] : nil
  err = stacktrace ? "Chef run did not report 'Chef Client finished'." : nil

  case fail_if
  when Regexp
    return "stdout matched the following when it should not have:\n#{fail_if}", stacktrace if stdout =~ fail_if
  when String
    return "stdout included the following when it should not have:\n#{fail_if}", stacktrace if stdout.include?(fail_if)
  end unless fail_if.nil?

  # Each chef run can only fail due to one reason, so if it was an expected error, we can simply return nil
  [' RuntimeError: ', ' NoMethodError: ', ' TypeError: ', ' ERROR: ', ' FATAL: '].each do |e|
    the_error = (stdout.split(e).last).split("\n")[0...-1].join("\n")
    case expected
    when Regexp
      if e + the_error =~ expected
        return nil, nil
      else
        return "#{e.strip}\n#{the_error}", stacktrace
      end
    when String
      if (e + the_error).include?(expected)
        return nil, nil
      else
        return "#{e.strip}\n#{the_error}", stacktrace
      end
    else
      return "#{e.strip}\n#{the_error}", stacktrace
    end if stdout.include?(e)
  end if err

  return err, stacktrace if expected.nil?

  case expected
  when Regexp
    return "stdout did not match the following when it should have:\n#{expected}", stacktrace unless stdout =~ expected
  when String
    return "stdout did not include the following when it should have:\n#{expected}", stacktrace unless stdout.include?(expected)
  end

  [err, stacktrace]
end

# data = {
#   :recipe => 'recipe to test, must be given',
#   :expected => 'fail if not match, can be errors',
#   :fail_if => 'fail if match'
# }
RSpec::Matchers.define :converge_test_recipe do |data = {}|
  fail 'All tests require a :recipe.' unless data[:recipe]
  match do
    stdout = chef_run(data[:recipe])

    dir = RSpec.configuration.log_dir + '/' + File.dirname(data[:recipe])
    FileUtils.mkdir_p(dir)

    log_basename = File.basename(data[:recipe], '.*')
    File.open(get_unique_file("./#{dir}", log_basename, '.stdout.log'), 'w+') { |file| file.write(stdout) }

    @error_message, stacktrace = get_error(stdout, data[:expected], data[:fail_if])
    @error_message = format_error(@error_message) unless @error_message.nil?

    FileUtils.cp(stacktrace, get_unique_file("./#{dir}", log_basename, '.stacktrace.out')) if stacktrace

    @error_message.nil?
  end
  failure_message do
    @error_message
  end
end
