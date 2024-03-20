# Copyright (c) 2018 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require "rails_helper"
include ActiveJob::TestHelper

RSpec.describe ParticipantMailer, type: :mailer do
  def expect_email_was_sent
    expect(ActionMailer::Base.deliveries.count).to eq(1)
  end

  before :each do
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  after(:each) do
    ActionMailer::Base.deliveries.clear
    Event.destroy_all
  end

  describe '.rsvp_confirmation' do
    before do
      @invitation = create(:invitation)
      @membership = @invitation.membership
      @membership.event.update_columns(event_format: 'Physical')
    end

    before :each do
      ParticipantMailer.rsvp_confirmation(@membership).deliver_now
      @sent_message = ActionMailer::Base.deliveries.first
    end

    it 'sends email' do
      expect_email_was_sent
    end

    it 'From: Setting.Emails["rsvp"]' do
      from_address = GetSetting.email(@membership.event.location, 'rsvp')
      expect(@sent_message.from).to include(from_address)
    end

    it 'To: confirmed participant' do
      expect(@sent_message.to).to include(@membership.person.email)
    end

    it 'uses default template for physical meetings' do
      expect(@sent_message.text_part.body.to_s).to include('attend the event')
    end
  end

  describe '.rsvp_confirmation for online meetings' do
    before do
      event = create(:event, name: 'Test Online Event', event_format: 'Online')
      @membership = create(:membership, event: event)
      create(:invitation, membership: @membership)
    end

    before :each do
      ParticipantMailer.rsvp_confirmation(@membership).deliver_now
      @sent_message = ActionMailer::Base.deliveries.first
    end

    it 'uses "Virtual" template for online meetings' do
      expect(@sent_message.body.to_s).to include('attend the online event')
    end

    it 'does not include PDF attachment for online meetings' do
      expect(@sent_message.attachments).to be_empty
    end
  end

  describe '.rsvp_confirmation for hybrid meetings' do
    before do
      @event = create(:event, name: 'Test Hybrid Event', event_format: 'Hybrid')
    end

    context 'for in-person participants' do
      before do
        @membership = create(:membership, event: @event, role: 'Participant')
        create(:invitation, membership: @membership)

        ParticipantMailer.rsvp_confirmation(@membership).deliver_now
        @sent_message = ActionMailer::Base.deliveries.first
      end

      it 'To: confirmed participant' do
        expect(@sent_message.to).to include(@membership.person.email)
      end

      it 'uses default template for physical meetings' do
        expect(@sent_message.text_part.body.to_s).to include('attend the event')
      end
    end

    context 'for online participants' do
      before do
        @membership = create(:membership, event: @event, role: 'Virtual Participant')
        create(:invitation, membership: @membership)

        ParticipantMailer.rsvp_confirmation(@membership).deliver_now
        @sent_message = ActionMailer::Base.deliveries.last
      end

      it 'To: confirmed participant' do
        expect(@sent_message.to).to include(@membership.person.email)
      end

      it 'uses "Virtual" template for online meetings' do
        expect(@sent_message.body.to_s).to include('attend the online event')
      end

      it 'does not include PDF attachment for online meetings' do
        expect(@sent_message.attachments).to be_empty
      end
    end
  end
end
