# app/mailers/invitation_mailer.rb
#
# Copyright (c) 2025 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

class InvitationMailer < ApplicationMailer
  prepend_view_path Liquid::Resolver.instance
  include InvitationMailerContext
  
  def invite(invitation)
    @invitation = invitation
    @membership = invitation.membership
    @person = @membership.person
    @event = @membership.event
    subject = "#{@event.location} Workshop Invitation: #{@event.name} (#{@event.code})"
    recipients = InvitationEmailRecipients.new(invitation).compose
    headers['X-BIRS-Sender'] = invitation.invited_by.to_s
    headers['X-BIRS-Event'] = invitation.event.code.to_s
    headers['X-Priority'] = 1
    headers['X-MSMail-Priority'] = 'High'
    
    # Get template selector
    selector = InvitationTemplateSelector.new(@membership)
    
    # Use both template_path AND template_name
    mail(
      to: recipients[:to],
      bcc: recipients[:bcc],
      from: recipients[:from],
      subject: subject,
      template_path: selector.relative_template_path,
      template_name: selector.template_name  # Added to use specific template names
    )
  end
end