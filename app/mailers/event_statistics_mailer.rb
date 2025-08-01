# frozen_string_literal: true

class EventStatisticsMailer < ApplicationMailer
  def notify(event_id:)
    @event = Event.find(event_id)

    @confirmed_count = Membership.in_person.confirmed.where(event: @event).count
    @invited_count = Membership.in_person.invited.where(event: @event).count
    @undecided_count = Membership.in_person.undecided.where(event: @event).count
    
    # Don't send annoying emails when there's no membership activity yet
    total_members = @confirmed_count + @invited_count + @undecided_count
    return if total_members.zero?
    
    @physical_spots = @event.max_participants - @confirmed_count - @invited_count - @undecided_count

    return if @physical_spots.zero?

    @program_coordinator = GetSetting.email(@event.location, 'program_coordinator')
    @contact_organizers = @event.contact_organizers
    @contact_organizers_names = @contact_organizers.map(&:dear_name).join(', ')

    recipients = []

    @contact_organizers.each do |organizer|
      recipients << to_email_address(organizer)
    end

    cc = GetSetting.email(@event.location, 'event_statistics_cc')

    subject = I18n.t('email.event_statistics.subject', location: @event.location, event_code: @event.code)

    mail(to: recipients, cc: cc, subject: subject, reply_to: @program_coordinator)
  end
end
