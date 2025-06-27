# app/services/syncable.rb
# Copyright (c) 2018 Banff International Research Station
#
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

# methods for SyncMember(s) & SyncPerson
module Syncable
  attr_writer :event, :local_members

  def event
    @event ||= ::Event.new(time_zone: Event.last.time_zone)
  end

  def local_members
    @local_members ||= event.memberships.includes(:person)
  end

  def fix_remote_fields(h)
    return if h.blank?

    h['Person'] = Person.new.attributes if h['Person'].blank?
    h['Membership'] = Membership.new.attributes if h['Membership'].blank?

    h['Person'] = tidy_emails(h['Person'])
    h = update_updateds(h)

    if h['Membership']['role'] == 'Backup Participant'
      h['Membership']['attendance'] = 'Not Yet Invited'
    end
    h
  end

  def find_local_membership(remote_member)
    local_membership = local_members.detect do |membership|
      membership.person.legacy_id == remote_member['Person']['legacy_id']
    end

    if local_membership.nil?
      local_membership = local_members.detect do |membership|
        membership.person.email == remote_member['Person']['email']
      end
      if !local_membership.nil? && local_membership.person.legacy_id.blank?
        local_membership.person.legacy_id = remote_member['Person']['legacy_id']
      end
    end
    local_membership
  end

  def create_new_membership(remote_member)
    local_person = find_and_update_person(remote_member['Person'])
    if local_person.valid?
      if local_members.select { |m| m.person_id == local_person.id }.blank?
        membership = Membership.new(remote_member['Membership'])
        membership.person_id = local_person.id
        membership.event_id = @event.id
        save_membership(membership)
      end
    end
  end

  def get_local_person(remote_person)
    # Check both active AND deleted persons to prevent recreation
    person = Person.with_deleted.find_by(legacy_id: remote_person['legacy_id'].to_i) ||
             Person.with_deleted.find_by(email: remote_person['email'].downcase.strip)
    
    # If person is deleted, log and return nil (skip sync)
    if person&.deleted?
      Rails.logger.info "⏭️  Skipping sync for deleted person: #{person.name} (ID: #{person.id}, deleted: #{person.deleted_at})"
      return nil
    end
    
    person
  end

  def find_and_update_person(remote_person)
    local_person = get_local_person(remote_person)

    if local_person.blank?
      new_person = update_record(Person.new, remote_person)
      local_person = save_person(new_person)
    else
      local_person = update_record(local_person, remote_person)
      save_person(local_person)
    end
    local_person
  end

  def bool_value(value)
    value == true || value == 1
  end

  def boolean_fields(obj)
    return if obj.nil?

    fields = []
    obj.attribute_names.each do |field|
      fields << field if obj.type_for_attribute(field).type == :boolean
    end
    fields
  end

  def local_is_newer?(local, remote)
    rupdated = prepare_value('updated_at', remote['updated_at'])
    return true if rupdated.nil?

    local.updated_at >= rupdated
  end

  def skip_fields(v,k)
    v.blank? || k == 'legacy_id' || k == 'email'
  end

  # local is newer, but remote may still have data that local is missing
  def update_missing_data(local, remote)
    remote.each_pair do |k,v|
      next if skip_fields(v,k)

      local_value = local.send(k)
      next unless local_value.blank?

      v = prepare_value(k, v)
      next if v.nil? && local_value.blank?

      booleans = boolean_fields(local)
      v = bool_value(v) if booleans.include?(k)
      local.update_column(k.to_s, v) unless v.blank? # avoid updating updated_at
    end
    local
  end

  def update_record_updateds(local)
    local.updated_at = DateTime.new(1970,1,1) if local.updated_at.blank?
    local.updated_by = 'Workshops Import' if local.updated_by.blank?
    local
  end

  def dedupe(local, remote)
    # resolve duplicate person records with mismatched legacy_id or email
    # if its a legacy_id change, also update event associations on legacydb
    # if its an email change, User account may also need updating
    local = resolve_duplicates(local, remote, 'legacy_id')
    local = resolve_duplicates(local, remote, 'email')
  end

  def skip_update_fields(k)
    k == 'legacy_id' || k == 'email' || k == 'biography' || k == 'research_areas'
  end

  # local record, remote hash
  def update_record(local, remote)
    local = update_record_updateds(local)
    return update_missing_data(local, remote) if local_is_newer?(local, remote)

    local = dedupe(local, remote)

    booleans = boolean_fields(local)
    remote.each_pair do |k, v|
      next if skip_update_fields(k)
      v = prepare_value(k, v)
      v = bool_value(v) if booleans.include?(k)

      next if k == 'invited_by' unless v.blank?
      v = 'Workshops importer' if k == 'invited_by' && v.blank?

      if k == 'invited_on'
        if local.invited_on.blank? || local.invited_on.to_i < v.to_i
          local.invited_on = v
          local.invited_by = remote['invited_by']
        end
      end
      next if k == 'invited_on'
      local.send("#{k}=", v) if local.has_attribute?(k)
    end

    local
  end

  # find duplicate Person records based on email or legacy_id (mode)
  def resolve_duplicates(local, remote, mode)
    person = local
    return person if remote["#{mode}"].blank?

    other_person = Person.find_by("#{mode}": remote["#{mode}"])
    if other_person.blank?
      # no local record with remote['legacy_id'], so replace the remote
      # record with the local record (found by email match). If either record
      # has no legacy_id, or if they match, replace_remote() does nothing.
      replace_remote(Person.new(remote), local) if mode == 'legacy_id'
      person = update_email(local, remote['email']) if mode == 'email'
    else
      unless local.id == other_person.id
        person = merge_person_records(local, other_person)
      end
    end
    person
  end

  def update_email(person, email)
    return person if person.email == email

    person.email = email
    update_user_account(person, person)
    person
  end

  # keep the record with most associated data, merge the other
  def merge_person_records(p1, p2)
    replace_with = ComparePersons.new(p1, p2).better_record
    replace = replace_with.eql?(p1) ? p2 : p1
    replace_person(replace: replace, replace_with: replace_with)
    replace_with
  end

  def update_ats(k, v)
    if k.to_s.include?('_at')
      v = nil if v == '0000-00-00 00:00:00' || v.blank?
      v = convert_to_time(v) unless v.nil?
    end
    v
  end

  def ids_to_int(k, v)
    v = v.to_i if k.include? '_id'
    v
  end

  def prepare_value(k, v)
    v = ids_to_int(k, v)
    v = update_ats(k, v)
    v = v.strip if v.respond_to? :strip
    v
  end

  def convert_to_time(v)
    Time.zone = ActiveSupport::TimeZone.new(event.time_zone)
    return Time.at(v) if v.is_a?(Integer)

    return v.in_time_zone(event.time_zone) if v.is_a?(Time) || v.is_a?(DateTime)

    begin
      time = Time.parse(v.to_s)
    rescue ArgumentError
      time = nil
    end
    time
  end

  def replace_person(replace: other_person, replace_with: person)
    ActiveRecord::Base.transaction do
      Rails.logger.info "Person merge starting: replacing #{replace.email} (ID: #{replace.id}) with #{replace_with.email} (ID: #{replace_with.id})"
      
      replace.memberships.each do |m|
        replace_with_membership = Membership.where(event: m.event,
                                                  person: replace_with).first
        m.sync_memberships = true
        if replace_with_membership.blank?
          Rails.logger.info "Moving membership #{m.id} from person #{replace.id} to person #{replace_with.id} for event #{m.event.code}"
          m.update(person: replace_with)
        else
          Rails.logger.warn "MEMBERSHIP DELETION: About to delete membership #{m.id} for person #{replace.email} in event #{m.event.code} due to duplicate with membership #{replace_with_membership.id}"
          
          invitation_count = Invitation.where(membership: m).count
          Rails.logger.warn "This will affect #{invitation_count} invitation(s) - moving to existing membership #{replace_with_membership.id}"
          
          Invitation.where(membership: m).each do |i|
            Rails.logger.info "Moving invitation #{i.id} from membership #{m.id} to membership #{replace_with_membership.id}"
            i.update(membership: replace_with_membership)
          end
          
          Rails.logger.warn "HARD DELETE: Deleting membership #{m.id} for person #{replace.email} (#{replace.id}) in event #{m.event.code}"
          m.delete
        end
      end

      Lecture.where(person_id: replace.id).each do |l|
        Rails.logger.info "Moving lecture #{l.id} from person #{replace.id} to person #{replace_with.id}"
        l.update(person: replace_with)
      end

      update_user_account(replace, replace_with)

      # Update legacy database
      replace_remote(replace, replace_with)

      # there can be only one!
      Rails.logger.warn "HARD DELETE: Deleting person record #{replace.id} (#{replace.email}) - replaced with #{replace_with.id} (#{replace_with.email})"
      replace.delete
      
      Rails.logger.info "Person merge completed successfully"
    end
  rescue => e
    Rails.logger.error "Person merge failed: #{e.message}"
    Rails.logger.error "Rollback performed - no data was lost"
    raise e
  end

  def update_user_account(person, replace_with)
    user_account = User.find_by_email(replace_with.email) ||
                   User.find_by_person_id(replace_with.id) ||
                   User.find_by_email(person.email) ||
                   User.find_by_person_id(person.id)

    unless user_account.nil?
      user_account.person = replace_with
      user_account.email = replace_with.email
      user_account.skip_reconfirmation!
      user_account.save
    end
  end

  def replace_remote(replace, replace_with)
    return if replace.legacy_id.blank? || replace_with.legacy_id.blank?

    return if replace.legacy_id.to_i == replace_with.legacy_id.to_i

    ReplacePersonJob.perform_later(replace.legacy_id, replace_with.legacy_id)
  end

  def save_person(person)
    person.member_import = true
    if person.valid? && person.save
      unless person.previous_changes.empty?
        Rails.logger.info "\n\n* Saved #{@event.code} person: #{person.name}\n"
      end
    else
      Rails.logger.error "\n\n" + "* Error saving #{@event.code} person:
        #{person.name}, #{person.errors.full_messages}".squish + "\n"
      sync_errors.add(person)
    end
    person
  end

  def save_membership(membership)
    membership.person.member_import = true
    membership.sync_memberships = true
    if membership.save
      unless membership.previous_changes.empty?
        Rails.logger.info "\n\n" + "* Saved #{membership.event.code} membership for
          #{membership.person.name}".squish + "\n"
      end
    else
      Rails.logger.error "\n\n" + "* Error saving #{membership.event.code} membership for
        #{membership.person.name}:
        #{membership.errors.full_messages}".squish + "\n"
        sync_errors = ErrorReport.new(self.class, @event)
        sync_errors.add(membership)
        sync_errors.send_report
    end
    membership
  end

  def tidy_emails(p)
    p['email'] = p['email'].downcase.strip unless p['email'].blank?
    p['cc_email'] = p['cc_email'].downcase.strip unless p['cc_email'].blank?
    p
  end

  def update_updateds(h)
    h.each do |_k, attr|
      if attr.key?('updated_by')
        attr['updated_by'] = 'Workshops importer' if attr['updated_by'].blank?
      end
      attr['updated_at'] = fixtime(attr['updated_at']) if attr.key?('updated_at')
    end
    h
  end

  def fixtime(val)
    return DateTime.current.in_time_zone(event.time_zone) if blank_time?(val)

    val
  end

  def blank_time?(val)
    val.blank? || val == '0000-00-00 00:00:00'
  end
end
