# frozen_string_literal: true

module Que
  class RemindExpiringInvitesJob < Job
    def run
      Rails.logger.info "Running RemindExpiringInvitesJob at #{Time.current}"
      send_week_expiry_reminder
      send_day_expiry_reminder
    end

    private

    def send_week_expiry_reminder
      Invitation.where(expires: (Date.current + 1.week).all_day).find_each do |invite|
        AttendanceConfirmationMailer.remind(invitation_id: invite.id, expiry_days: 7).deliver_now
        Rails.logger.info "Sent reminder for #{invite.id} with expiry in 7 days"
      end
    end

    def send_day_expiry_reminder
      Invitation.where(expires: Date.current.all_day).find_each do |invite|
        AttendanceConfirmationMailer.remind(invitation_id: invite.id, expiry_days: 1).deliver_now
        Rails.logger.info "Sent reminder for #{invite.id} with expiry today"
      end
    end
  end
end
