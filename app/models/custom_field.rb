# frozen_string_literal: true

class CustomField < ApplicationRecord
  belongs_to :event

  validates :title, presence: true
end
