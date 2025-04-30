# Copyright (c) 2025 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

# Configure YAML to allow DateTime objects
if defined?(YAML)
  # Make sure we can deserialize DateTime objects
  YAML.load_tags['!ruby/object:DateTime'] = DateTime
  
  # Don't monkey patch anything else - this is causing the errors
  # Just use the defaults and let Rails handle serialization
end

# This is really all we need to fix the Psych::DisallowedClass error for DateTime
module Psych
  if defined?(Psych::ClassLoader)
    class ClassLoader
      def initialize
        @classes = {}
      end
      
      def find(klassname, fallback: true)
        return @classes[klassname] if @classes.key?(klassname)
        
        # Always allow DateTime objects
        return DateTime if klassname == 'DateTime'
        
        # Standard Psych behavior
        begin
          klass = klassname.split('::').inject(Object) do |k, c|
            k.const_get(c, false)
          end
          @classes[klassname] = klass
        rescue NameError
          raise unless fallback
          nil
        end
      end
    end
  end
end