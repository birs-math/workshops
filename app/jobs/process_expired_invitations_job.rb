# app/jobs/process_expired_invitations_job.rb
#
# Copyright (c) 2025 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

# Automatically processes expired invitations by marking them as declined
class ProcessExpiredInvitationsJob < ApplicationJob
  queue_as :default

  def perform
    expired_invitations = Invitation.where("expires < ?", DateTime.now)
    
    expired_invitations.each do |invitation|
      membership = invitation.membership
      
      # Update membership status to "Declined" with reason
      membership.attendance = 'Declined'
      membership.replied_at = DateTime.current
      membership.updated_by = "System: Invitation Expired"
      membership.update_remote = true
      membership.is_rsvp = true # don't resend organizer notice
      
      # Log the expiration
      Rails.logger.info "\n\n*** EXPIRED: Invitation for #{membership.person.name} " +
        "(#{membership.person_id}) has expired for " +
        "#{membership.event.code} ***\n\n".squish
      
      # Send notification email
      EmailExpiredInvitationJob.perform_later(membership.id, invitation.expires)
      
      # Save membership changes
      begin
        membership.save!
        
        # Delete the invitation after successful membership update
        invitation.destroy
      rescue ActiveRecord::RecordInvalid => error
        params = { 'error' => error.to_s, 'membership' => membership.inspect }
        EmailFailedRsvpJob.perform_later(membership.id, params)
      end
    end
  end
end
