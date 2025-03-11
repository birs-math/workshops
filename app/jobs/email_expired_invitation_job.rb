# app/jobs/email_expired_invitation_job.rb
#
# Copyright (c) 2025 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

# Initiates ExpiredInvitationMailer to notify participants of expired invitations
class EmailExpiredInvitationJob < ApplicationJob
  queue_as :urgent

  def perform(membership_id, expiry_date)
    membership = Membership.find_by_id(membership_id)
    return if membership.blank?
    
    ExpiredInvitationMailer.notify(membership, expiry_date).deliver_now
  end
end
