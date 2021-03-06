# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require "rails_helper"
include ActiveJob::TestHelper

RSpec.describe InvitationMailer, type: :mailer do
  def expect_email_was_sent
    expect(ActionMailer::Base.deliveries.count).to eq(1)
  end

  before :each do
    ActionMailer::Base.deliveries.clear
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  describe '.invite' do
    before do
      membership = create(:membership, attendance: 'Not Yet Invited')
      @invitation = create(:invitation, membership: membership)
      @invitation.set_invitation_template
    end

    before :each do
      InvitationMailer.invite(@invitation).deliver_now
      @delivery = ActionMailer::Base.deliveries.first
      expect(@delivery).not_to be_nil
      @body = @delivery.body.empty? ? @delivery.text_part : @delivery.body
    end

    it 'sends email' do
      expect_email_was_sent
    end

    it 'To: given member, subject: event_code' do
      expect(@delivery.to_addrs.first).to eq(@invitation.membership.person.email)
      expect(@delivery.subject).to include(@invitation.membership.event.code)
    end

    it "message body includes participant's name" do
      participant_name = @invitation.membership.person.dear_name

      expect(@body).to have_text(participant_name)
    end

    it 'message body includes the invitation code' do
      expect(@body).to have_text(@invitation.code)
    end

    it 'message body contains event name' do
      event_name = @invitation.membership.event.name
      expect(@body).to have_text(event_name)
    end

    it 'message body includes formatted dates' do
      start_date = @invitation.membership.event.start_date_formatted
      expect(@body).to have_text(start_date)

      end_date = @invitation.membership.event.end_date_formatted
      expect(@body).to have_text(end_date)
    end

    it 'headers include the senders name and event code' do
      senders_name_header = "X-BIRS-Sender: #{@invitation.invited_by}"
      expect(@delivery.header).to have_text(senders_name_header)

      event_code_header = "X-BIRS-Event: #{@invitation.membership.event.code}"
      expect(@delivery.header).to have_text(event_code_header)
    end

    it 'includes bcc to rsvp address' do
      rsvp_email = GetSetting.rsvp_email(@invitation.event.location)
      expect(@delivery.bcc.first).to eq(rsvp_email)
    end

    it 'invitations to physical meetings include a PDF attachment' do
      event = create(:event, event_format: 'Physical',
                               event_type: '5 Day Workshop')
      membership = create(:membership, event: event,
                                  attendance: 'Not Yet Invited')
      invitation = create(:invitation, membership: membership)
      invitation.set_invitation_template

      InvitationMailer.invite(invitation).deliver_now
      delivery = ActionMailer::Base.deliveries.last

      expect(delivery.attachments).not_to be_empty
      template = InvitationTemplateSelector.new(membership).set_templates
      expect(delivery.attachments[0].filename).to eq(template[:invitation_file])
    end
  end

  describe 'RSVP deadline' do
    before do
      membership = create(:membership, attendance: 'Not Yet Invited')
      @invitation = create(:invitation, membership: membership)
      @invitation.set_invitation_template
      @event = @invitation.membership.event
      @today = DateTime.current.in_time_zone(@event.time_zone)
    end

    context 'Physical events' do
      before do
        @event.update_columns(event_format: 'Physical')
      end

      it 'sets date to 4 weeks in advance of current date' do
        @event.start_date = @today + 5.months
        @event.end_date = @event.start_date + 5.days
        @event.save

        InvitationMailer.invite(@invitation).deliver_now
        delivery = ActionMailer::Base.deliveries.first
        body = delivery.body.empty? ? delivery.text_part : delivery.body

        rsvp_date = (@today + 4.weeks).strftime('%B %-d, %Y')
        expect(body).to have_text("before #{rsvp_date}")
      end

      it 'sets date to the previous Tuesday, or tomorrow if event in 10 days' do
        @event.start_date = @today + 8.days
        @event.end_date = @event.start_date + 5.days
        @event.save

        InvitationMailer.invite(@invitation).deliver_now
        delivery = ActionMailer::Base.deliveries.first
        body = delivery.body.empty? ? delivery.text_part : delivery.body
        rsvp_date = @event.start_date.prev_occurring(:tuesday)

        # unless Tuesday is in the past. In which case, set reply-by to tomorrow
        if rsvp_date < @today
          tomorrow = (@today + 1.day).strftime('%B %-d, %Y')
          expect(body).to have_text("before #{tomorrow}")
        else
          expect(body).to have_text("before #{rsvp_date.strftime('%B %-d, %Y')}")
        end
      end

      it 'sets date to 10 days in advance if event is < 2 months away' do
        @event.start_date = @today + 1.month + 3.weeks
        @event.end_date = @event.start_date + 5.days
        @event.save

        InvitationMailer.invite(@invitation).deliver_now
        delivery = ActionMailer::Base.deliveries.first
        body = delivery.body.empty? ? delivery.text_part : delivery.body

        rsvp_date = (@today + 10.days).strftime('%B %-d, %Y')
        expect(body).to have_text("before #{rsvp_date}")
      end

      it 'sets date to 21 days in advance if event is < 3 months, 5 days away' do
        @event.start_date = @today + 3.months
        @event.end_date = @event.start_date + 5.days
        @event.save

        InvitationMailer.invite(@invitation).deliver_now
        delivery = ActionMailer::Base.deliveries.first
        body = delivery.body.empty? ? delivery.text_part : delivery.body

        rsvp_date = (@today + 21.days).strftime('%B %-d, %Y')
        expect(body).to have_text("before #{rsvp_date}")
      end
    end

    context 'Online events' do
      before do
        @event.update_columns(event_format: 'Online')
      end

      it 'sets date to the last day of the workshop' do
        InvitationMailer.invite(@invitation).deliver_now
        delivery = ActionMailer::Base.deliveries.first
        body = delivery.body.empty? ? delivery.text_part : delivery.body

        rsvp_date = @event.end_date.to_time.strftime('%B %-d, %Y')
        expect(body).to have_text("before #{rsvp_date}")
      end
    end

    context 'Hybrid events' do
      before do
        @event.update_columns(event_format: 'Hybrid')
      end

      it 'sets date to the last day of the workshop for virtual participants' do
        @invitation.membership.update_columns(role: 'Virtual Participant')

        InvitationMailer.invite(@invitation).deliver_now
        delivery = ActionMailer::Base.deliveries.first
        body = delivery.body.empty? ? delivery.text_part : delivery.body

        rsvp_date = @event.end_date.to_time.strftime('%B %-d, %Y')
        expect(body).to have_text("before #{rsvp_date}")
      end

      it 'sets dates to the same as Physical workshops, for non-Virtual' do
        @invitation.membership.update_columns(role: 'Participant')

        @event.start_date = @today + 5.months
        @event.end_date = @event.start_date + 5.days
        @event.save

        InvitationMailer.invite(@invitation).deliver_now
        delivery = ActionMailer::Base.deliveries.first
        body = delivery.body.empty? ? delivery.text_part : delivery.body

        rsvp_date = (@today + 4.weeks).strftime('%B %-d, %Y')
        expect(body).to have_text("before #{rsvp_date}")
      end
    end
  end
end
