# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

class EventPolicy
  attr_reader :current_user, :event

  def initialize(current_user, model)
    @current_user = current_user
    @event = model.nil? ? Event.new : model
  end

  def method_missing(name, *args)
    if current_user
      if staff_at_location
        event.template && name.match?(/edit|update/)
      else
        current_user.is_admin?
      end
    end
  end

  # Only staff can see template events at their location
  class Scope < Struct.new(:current_user, :model)
    def resolve
      if current_user && (current_user.is_admin? || current_user.staff?)
        return model.all.order(:start_date) if current_user.is_admin?

        location = current_user.location
        model.where
             .not('(template = ? AND location != ?)', true, location)
             .order(:start_date)
      else
        model.where(template: false).where.not(state: :imported).order(:start_date)
      end
    end
  end

  def update?
    organizers_and_staff
  end

  def edit?
    organizers_and_staff
  end

  def may_edit
    all_fields = (event.attributes.keys.sort + %w[custom_fields_attributes]) - %w[id updated_by created_at
                                                                                  updated_at confirmed_count
                                                                                  publish_schedule sync_time]
    case current_user.role
    when 'admin', 'super_admin'
      all_fields
    when 'staff'
      all_fields - %w[code name start_date end_date location event_type
                      time_zone template]
    when 'member'
      if current_user.is_organizer?(event)
        %w[short_name subjects description press_release]
      else
        []
      end
    else
      []
    end
  end

  def show?
    if event.template
      staff_and_admins
    elsif event.imported?
      current_user.is_organizer?(event) || staff_and_admins
    else
      true
    end
  end

  def delete?
    current_user.admin? || current_user.super_admin?
  end

  def allow_add_members?
    return false if current_user.nil?
    return true if staff_and_admins
    return false if Date.current > event.end_date

    organizers_and_staff
  end

  def view_attendance_status?(status)
    return true if organizers_and_staff_readonly

    ['Confirmed'].include?(status) if current_user
  end

  def show_email_buttons?(status)
    return false if current_user.nil?
    return true if organizers_and_staff

    status == 'Confirmed' && current_user.is_confirmed_member?(event)
  end

  def send_invitations?
    return false if current_user.nil? || Date.current > event.end_date

    organizers_and_staff
  end

  def sync?
    organizers_and_staff if event.end_date >= Time.zone.today && !event.template && !Rails.env.test?
  end

  def view_details?
    return false if current_user.nil?

    member_of_event? || staff_and_admins
  end

  def event_staff?
    staff_and_admins
  end

  def generate_report?
    staff_and_admins
  end

  alias see_summary? generate_report?

  private

  def staff_at_location
    return false unless current_user

    current_user.staff? && current_user.location == event.location
  end

  def staff_and_admins
    return false unless current_user

    current_user.is_admin? || staff_at_location
  end

  def organizers_and_staff
    return false unless current_user

    (event.active? && current_user.is_organizer?(event)) || current_user.is_admin? || staff_at_location
  end

  def organizers_and_staff_readonly
    return false unless current_user

    current_user.is_organizer?(event) || current_user.is_admin? || staff_at_location
  end

  def member_of_event?
    return false unless current_user

    member = Membership.where(person: current_user.person, event: @event).first
    return false if member.blank?

    %w[Confirmed Invited Undecided].include?(member.attendance)
  end
end
