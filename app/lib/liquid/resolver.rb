# frozen_string_literal: true

# Copyright (c) 2023 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'singleton'

class Liquid::Resolver < ActionView::Resolver
  include Singleton

  def find_templates(name, prefix, _partial, _details, _locals = [])
    EmailNotification.resolver_lookup(path: build_path(name, prefix)).map do |record|
      to_template(record)
    end
  end

  def build_path(name, prefix)
    "#{prefix}/#{name}"
  end

  def to_template(record)
    identifier = "#{record.class} - #{record.id} - #{record.path}"
    handler = ActionView::Template.registered_template_handler(record.handler)

    # format column is nullable; Rails 6 requires a symbol and rejects nil
    ActionView::Template.new(record.body, identifier, handler,
                             format: (record.format || 'html').to_sym,
                             virtual_path: record.path)
  end
end
