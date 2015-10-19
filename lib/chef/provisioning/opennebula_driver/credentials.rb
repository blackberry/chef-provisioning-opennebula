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
        def initialize
          @credentials = {}
          load_default
        end

        def default
          fail 'No credentials loaded!  Do you have a ~/.one/one_auth file?' if @credentials.size == 0
          @credentials[ENV['ONE_DEFAULT_PROFILE'] || 'default'] || @credentials.first[1]
        end

        def [](name)
          @credentials[name]
        end

        def load_default
          oneauth_file = ENV['ONE_AUTH'] || File.expand_path('~/.one/one_auth')
          @credentials['default'] = File.read(oneauth_file).strip! if File.file?(oneauth_file)
        end
      end
    end
  end
end
