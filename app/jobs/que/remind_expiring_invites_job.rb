# frozen_string_literal: true

module Que
  class RemindExpiringInvitesJob < Job
    def run
      send_week_expiry_reminder
      send_day_expiry_reminder
    end

    private

    def send_week_expiry_reminder
      Invitation.no_rsvp_from_confirmed.where(expires: (Date.current + 1.week).all_day).find_each do |invite|
        AttendanceConfirmationMailer.remind(invitation_id: invite.id, expiry_days: 7).deliver_now
      end
    end

    def send_day_expiry_reminder
      Invitation.no_rsvp_from_confirmed.where(expires: Date.current.all_day).find_each do |invite|
        AttendanceConfirmationMailer.remind(invitation_id: invite.id, expiry_days: 1).deliver_now
      end
    end
  end
end
