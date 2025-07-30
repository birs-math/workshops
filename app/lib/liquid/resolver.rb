# frozen_string_literal: true
# Copyright (c) 2025 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.
require 'singleton'

module Liquid
  class Resolver < ActionView::Resolver
    include Singleton

    def find_templates(name, prefix, partial, details, outside_app_allowed = false)
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
      format = record.format.present? ? record.format.to_sym : :html
      
      # Updated for Rails 6.1.7 compatibility
      ActionView::Template.new(
        record.body,
        identifier,
        handler,
        locals: [],
        format: format,
        virtual_path: record.path
      )
    end
  end
end

