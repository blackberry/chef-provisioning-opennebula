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

require 'chef/provisioning/opennebula_driver'
require 'open3'
require 'tempfile'
require 'fileutils'
require "#{File.dirname(__FILE__)}/config.rb"

RSpec.configure do |config|
  config.filter_run :runme
  config.run_all_when_everything_filtered = true
  config.add_setting :log_dir, :default => File.join(File.expand_path('..', File.dirname(__FILE__)), 'rspec-results')
  config.before(:suite) do
    # Cleanup nodes and log_dir from previous run
    FileUtils.rm_rf(File.join(File.expand_path('..', File.dirname(__FILE__)), 'nodes'))
    FileUtils.mkdir_p(config.log_dir) unless Dir.exist?(config.log_dir)
    Dir.entries(config.log_dir).reject{|entry| entry =~ /^\.\.?$/}.each do |f|
      FileUtils.rm_rf(File.join(config.log_dir, f))
    end
    cleanup
  end
  config.after(:suite) do
    FileUtils.rm_rf(File.join(File.expand_path('..', File.dirname(__FILE__)), 'nodes'))
  end
end

RSpec::Matchers.define :converge_with_result do |expected|
  match do |recipe|
    recipe_file = createRecipe([File.join('./spec/recipes/', recipe)])
    @stdout, @stderr, status = Open3.capture3('chef-client', '-z', recipe_file, '--force-formatter')

    # Save stdout, stderr and stacktrace to log_dir
    saveLogs(recipe, @stdout, @stderr)

    # Evaluate outcome by looking at STDOUT
    if status.success?
      @stdout.scan(Regexp.union(expected)).any? ? true : false
    else
      false
    end
  end

  failure_message do |recipe|
    "expecting #{recipe} return #{expected} - instead we received:\n\n#{@stdout}\n#{@stderr}"
  end

  failure_message_when_negated do |recipe|
    "expecting #{recipe} NOT return #{expected} - instead we received:\n\n#{@stdout}\n#{@stderr}"
  end
end

private

# Create a temporary recipe file
# NB - file is removed after rspec terminates
def createRecipe(recipes_list)
  recipes_list.unshift('./spec/recipes/common.rb')
  file = Tempfile.new(['recipe-', '.rb'], '/tmp')
  file << "require '#{File.dirname(__FILE__)}/config.rb'\n\n"
  recipes_list.each do |r|
    file << File.read(r) + "\n\n"
  end
  file.close
  file.path
end

# Save output streams and stacktrace to log files
# Log filenames are timestamped to make then unique
def saveLogs(recipe, stdout, stderr)
  # Establish what filename to use for logging
  FileUtils.mkdir_p(File.join(RSpec.configuration.log_dir, File.dirname(recipe)))
  log_basename = File.join(RSpec.configuration.log_dir, File.dirname(recipe),
                           File.basename(recipe, File.extname(recipe)))
  ts = Time.now.strftime('%H-%M-%S-%4N')

  # Find out if we have a stacktrace in stdout
  st = @stdout.scan(/FATAL: Stacktrace dumped to (.*?chef-stacktrace\.out)/)
  stacktrace = st.any? && File.exist?(st.last.join) ? File.read(st.last.join) : ''

  # Write the logs
  File.open(log_basename + ".#{ts}" + '.stdout', 'w') { |f| f.puts(stdout); f.close} unless stdout.empty?
  File.open(log_basename + ".#{ts}" + '.stderr', 'w') { |f| f.puts(stderr); f.close} unless stderr.empty?
  File.open(log_basename + ".#{ts}" + '.stacktrace', 'w') { |f| f.puts(stacktrace); f.close} unless stacktrace.empty?
end

# Cleanup objects created in previous run
def cleanup
  # List of recipes we're going to use for cleanup
  cleanup_list = %w(
    OneDriver/delete_one_snap-img.rb
    OneDriver/delete_one_vm.rb
    OneDriver/delete_one_template.rb
    OneDriver/delete_one_img.rb
    OneDriver/delete_one_vnet.rb
  ).map { |f| File.join(File.dirname(__FILE__), "recipes", f) }
  cleanup_list += Dir["#{File.dirname(__FILE__)}/recipes/OneFlow/delete_*.rb"] unless ONE_FLOW_URL.nil?

  # Create temporary cleanup recipe and run it
  recipe_file = createRecipe(cleanup_list)
  @stdout, @stderr, status = Open3.capture3('chef-client', '-z', recipe_file, '--force-formatter')

  # Save stdout, stderr and stacktrace to log_dir
  saveLogs('cleanup.rb', @stdout, @stderr)

  # Evaluate outcome by looking at STDOUT
  if status.success?
    raise "Cleanup attempt failed:\n\n#{@stdout}\n#{@stderr}" if @stdout.scan(/FATAL:/).any?
  else
    raise "Cleanup attempt failed:\n\n#{@stdout}\n#{@stderr}"
  end
end
