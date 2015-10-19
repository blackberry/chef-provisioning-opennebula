

class Chef
  module Provisioning
    module OpenNebulaDriver
      class Credentials

        def initialize
          @credentials = {}
          load_default
        end

        def default
          if @credentials.size == 0
            raise 'No credentials loaded!  Do you have a ~/.one/one_auth file?'
          end
          @credentials[ENV['ONE_DEFAULT_PROFILE'] || 'default'] || @credentials.first[1]
        end

        def [](name)
          @credentials[name]
        end

        def load_default
          oneauth_file = ENV['ONE_AUTH'] || File.expand_path('~/.one/one_auth')
          if File.file?(oneauth_file)
            @credentials['default'] = File.read(oneauth_file)
            @credentials['default'].strip!
          end
        end

      end
    end
  end
end
