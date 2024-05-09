# frozen_string_literal: true
class SendInvitationsJob < ApplicationJob
  queue_as :urgent

  def perform(event_id:, invited_by:)
    @event = Event.find(event_id)
    @invited_by = invited_by

    send_invitations
  end

  private

  def send_invitations
    @event.memberships.not_yet_invited.each do |membership|
      Invitation.new(membership: membership, invited_by: @invited_by).send_invite
    end
  end
end
