# app/models/confirm_email_change.rb
# Copyright (c) 2019 Banff International Research Station
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# If user requests changing email and another record has that email,
# this will send confirmation links to both addresses to confirm ownership
# before one person record is replaced with the other
class ConfirmEmailChange < ApplicationRecord
  attr_accessor :replace_person_obj, :replace_with_obj
  has_many :people
  belongs_to :replace_person, class_name: 'Person', optional: true
  belongs_to :replace_with, class_name: 'Person', optional: true
  validates :replace_person, presence: true
  validates :replace_with, presence: true
  # validate :already_exists?, on: :create

  after_initialize :generate_codes
  before_save :set_values

  def already_exists?
    unless ConfirmEmailChange.where(replace_person_id: replace_person.id,
                                      replace_with_id: replace_with.id,
                                      confirmed: false).blank?
      errors.add(:replace_person, "already pending for this record")
    end
  end

  def generate_codes
    if self.replace_code.blank?
      self.replace_code = SecureRandom.alphanumeric(8)
    end
    if self.replace_with_code.blank?
      self.replace_with_code = SecureRandom.alphanumeric(8)
    end
  end

  def set_values
    if replace_person_obj
      self.replace_person_id ||= replace_person_obj.id
      self.replace_email ||= replace_person_obj.email
    end
    if replace_with_obj
      self.replace_with_id ||= replace_with_obj.id
      self.replace_with_email ||= replace_with_obj.email
    end
  end

  def send_email
    ConfirmEmailReplacementJob.perform_later(self.id)
  end

  def related_conflicts
    # Find all conflicts involving the same email addresses
    email_addresses = [replace_email, replace_with_email].compact.uniq
    
    ConfirmEmailChange.where(
      "(replace_email IN (?) OR replace_with_email IN (?)) AND id != ?",
      email_addresses, email_addresses, id
    ).where(confirmed: false)
  end

  def conflict_group_size
    related_conflicts.count + 1
  end
end
