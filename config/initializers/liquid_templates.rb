# frozen_string_literal: true

# Rails 7.0: Liquid::Handler is autoloadable; register inside to_prepare
Rails.application.config.to_prepare do
  ActionView::Template.register_template_handler(:liquid, Liquid::Handler)
end
