# app/services/sync_person.rb
# Copyright (c) 2018 Banff International Research Station
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

# updates one person record with data from remote db
class SyncPerson
  attr_reader :person, :new_email
  include Syncable

  def initialize(person, new_email = nil)
    @person = person
    @new_email = new_email.downcase.strip unless new_email.nil?
  end

  def sync_person
    return if person.legacy_id.blank?
    lc = LegacyConnector.new
    remote_person = lc.get_person(person.legacy_id)
    return if remote_person.blank?
    return if person.updated_at.to_i >= remote_person['updated_at'].to_i

    local_person = update_record(person, remote_person)
    save_person(local_person)
  end

  def names_match(n1, n2)
    return false if n1.blank? || n2.blank?
    
    # Normalize names for comparison
    norm1 = normalize_name(n1)
    norm2 = normalize_name(n2)
    
    # Exact match after normalization
    return true if norm1 == norm2
    
    # Check if names are similar enough (accounting for middle names, initials, etc.)
    similarity_match?(norm1, norm2)
  end

  private

  def normalize_name(name)
    I18n.transliterate(name.downcase.strip)
      .gsub(/[^\w\s]/, '') # Remove punctuation
      .squeeze(' ')        # Collapse multiple spaces
  end

  def similarity_match?(name1, name2)
    # Split names into parts
    parts1 = name1.split
    parts2 = name2.split
    
    # If either name has only one part, require exact match
    return false if parts1.length == 1 || parts2.length == 1
    
    # Check if first and last names match (allowing for middle name differences)
    first_match = parts1.first == parts2.first
    last_match = parts1.last == parts2.last
    
    # Require both first and last name to match for similarity
    first_match && last_match
  end

  def has_recent_invitations?(person)
    return false unless person.persisted?
    
    # Check for invitations created in the last 24 hours
    recent_threshold = 24.hours.ago
    person.memberships.joins(:invitations).where('invitations.created_at > ?', recent_threshold).exists?
  end

  public

  def find_other_person
    Person.where(email: @new_email).where.not(id: @person.id).first
  end

  def has_conflict?
    other_person = find_other_person
    return false if other_person.nil?
    !names_match(@person.name, other_person.name)
  end

  def change_email
    return @person if @person.email == @new_email

    # Person model validates, so send it back if email is invalid
    unless EmailValidator.valid?(@new_email)
      @person.email = @new_email
      return @person
    end

    other_person = find_other_person
    if other_person.nil?
      @person.email = @new_email
      return @person
    end

    if names_match(other_person.name, @person.name)
      # Check if either person has recent invitations (within 24 hours)
      if has_recent_invitations?(@person) || has_recent_invitations?(other_person)
        Rails.logger.warn "MERGE BLOCKED: Person #{@person.name} or #{other_person.name} has recent invitations - requiring manual confirmation"
        create_change_confirmation(@person, other_person)
      else
        Rails.logger.info "Auto-merging persons with matching names: #{@person.name} (#{@person.id}) and #{other_person.name} (#{other_person.id})"
        merge_person_records(@person, other_person)
        p = Person.find_by_id(@person.id) || Person.find_by_id(other_person.id)
        p.email = @new_email
        @person = p
      end
    else
      create_change_confirmation(@person, other_person)
    end

    @person
  end

  def create_change_confirmation(person, replace_with, reverse_emails: false)
    begin
      params = {
        replace_person: person,
        replace_with: replace_with,
        replace_email: person.email,
        replace_with_email: replace_with.email
      }
      if reverse_emails
        params.merge!(replace_email: replace_with.email,
                     replace_with_email: person.email)
      end
      confirmation = ConfirmEmailChange.create!(params)
    rescue ActiveRecord::RecordInvalid => e
      return person if e.message.match?(/Validation failed/)
      msg = { problem: 'Unable to create! new ConfirmEmailChange',
              source: 'SyncPerson.create_change_confirmation',
              person: "#{person.name} (id: #{person.id}",
              replace_with: "#{replace_with.name} (id: #{replace_with.id})",
              error: e.inspect }
      StaffMailer.notify_sysadmin(nil, msg).deliver_now
      return
    end
    confirmation.send_email
    confirmation
  end

  def confirmed_email_change(confirmation)
    replace_with_person = Person.find(confirmation.replace_with_id)
    replace_person(replace: @person, replace_with: replace_with_person)
  end
end
