# app/forms/invitation_form.rb
#
# Copyright (c) 2018 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

# Form at views/invitations/new.html.erb
class InvitationForm < ComplexForms
  attr_accessor :event, :email, :membership

  validate :selected_event
  validate :valid_email
  validate :is_member

  def initialize(attributes = {})
    @event = attributes['event']
    @email = attributes['email']
    @membership = nil
  end

  def selected_event
    if event.blank?
      errors.add(:event, ": You must select the event to which you were invited.")
    elsif event !~ /#{Setting.Site['code_pattern']}/
      errors.add(:event, ": Invalid event code.")
    else
      ev = Event.find(event)
      if ev.nil?
        errors.add(:event, ": No record of that event.")
      elsif ev.start_date < Date.today
        errors.add(:event, ": Event is in the past.")
      end
    end
  end

  def valid_email
    if email.blank?
      errors.add(:email, ": Your e-mail address is required to confirm your invitation.")
    elsif !EmailValidator.valid?(email)
      errors.add(:email, ": You must enter a valid e-mail address.")
    end
  end

  def is_member
    unless errors.any?
      person = Person.find_by_email(email)
      if person.nil?
        errors.add(:email, ": We have no record of that email address.
          Is it possible that we were given a different email address for you?")
        return false
      else
        e = Event.find(event)
        @membership = Membership.where(person: person, event: e).first

        if @membership.nil?
          errors.add(:email, ": that e-mail address is not associated to the
            event you selected. Do you have a different e-mail address that we
            might have in our records?")
          return false

        elsif @membership.attendance == 'Declined'
          errors.add(:Membership, ": You have already declined an invitation
            to this event. Please contact the event's organizers to ask if it
            is still possible to attend.<br />
            The contact organizer is: <u>#{organizer(e)}</u>.")

          elsif @membership.attendance == 'Not Yet Invited'
            errors.add(:Membership, ": The event's organizers have not yet
              invited you. Please contact them if you wish to be invited.<br />
              The contact organizer is: <u>#{organizer(e)}</u>.")
        else
          return true
        end
      end
    end
  end

  def organizer(event)
    om = event.memberships.select { |m| m.role == 'Contact Organizer' }.first
    link = ''
    if om.nil?
      event_url = Setting.Site['events_url'] + event.code
      link = '<a href="' + event_url + '">' + event_url + '</a>'
    else
      link = '<a href="mailto:'
      link += "'#{om.person.name}' <#{om.person.email}>"
      link += "?Subject=[#{event.code}] \">#{om.person.name}</a>".html_safe
    end
    link
  end
end
