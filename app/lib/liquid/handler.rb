
# frozen_string_literal: true
# Copyright (c) 2025 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.
module Liquid
  class Handler
    # Rails 6.1 changed the method signature for handlers
    # In Rails 6.1, handlers.call receives template and source
    def self.call(template, source = nil)
      # If only template is provided (Rails 6.1 style), extract source from template
      if source.nil? && template.respond_to?(:source)
        source = template.source
      end
      
      # For Rails 6.1.7, we need to be careful about how we handle local_assigns
      # to avoid the "undefined method `-' for {}:Hash" error
      <<-RUBY
        liquid_template = ::Liquid::Template.parse(#{source.inspect})
        
        # The key fix is ensuring local_assigns is properly handled
        # This is critical to avoid the Hash subtraction error
        assigns = {}
        
        if defined?(local_assigns) && local_assigns
          if local_assigns.respond_to?(:with_indifferent_access)
            assigns = local_assigns.with_indifferent_access
          elsif local_assigns.is_a?(Hash)
            assigns = local_assigns.dup
          end
        end
        
        liquid_template.render(assigns, registers: { view: self }).html_safe
      RUBY
    end
  end
end
ActionView::Template.register_template_handler :liquid, Liquid::Handler

