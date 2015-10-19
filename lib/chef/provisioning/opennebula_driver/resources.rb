resources = %w( image template )

resources.each do |r|
  Chef::Log.debug "OpenNebula driver loading resource: one_#{r}"
  require "chef/resource/one_#{r}"
end
