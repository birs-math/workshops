# Copyright (c) 2018 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'rails_helper'

# Griddler email processor
describe 'EmailProcessor' do
  let(:params) do
    {
      to: ['some-identifier@example.com'],
      recipient: 'some-identifier@example.com',
      from: 'Webmaster <webmaster@example.net>',
      subject: 'Testing email processing',
      text: 'A Test Message.',
      Date: "Tue, 25 Sep 2018 16:17:17 -0600",
      headers: {'Message-Id' => 'b901cee7-e49a-4330-9ee2-3fc28c6343cb@domain.edu'}
    }
  end

  subject { Griddler::Email.new(params) }

  let(:event) { create(:event) }
  let(:person) { create(:person) }
  let(:membership) { create(:membership, event: event, person: person) }
  let(:organizer) { create(:membership, event: event, role: 'Contact Organizer') }

  it '.initialize' do
    expect(EmailProcessor.new(subject).class).to eq(EmailProcessor)
  end

  context 'validates recipient' do
    it 'sends bounce email if no recipients contain event codes' do
      allow(EmailInvalidCodeBounceJob).to receive(:perform_later)
      EmailProcessor.new(Griddler::Email.new(params)).process
      expect(EmailInvalidCodeBounceJob).to have_received(:perform_later)
    end

    it 'sends bounce email if valid code format does not find an event' do
      params[:to] = ["03w5000@example.com"]
      allow(EmailInvalidCodeBounceJob).to receive(:perform_later)
      EmailProcessor.new(Griddler::Email.new(params)).process
      expect(EmailInvalidCodeBounceJob).to have_received(:perform_later)
    end

    it 'does not send invalid code bounce if recipient event code is valid' do
      params[:to] = ["#{event.code}@example.com"]
      params[:recipient] = "#{event.code}@example.com"
      email = Griddler::Email.new(params)
      allow(EmailInvalidCodeBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(EmailInvalidCodeBounceJob).not_to have_received(:perform_later)
    end

    it 'does not bounce email if at least one of multiple recipients is valid' do
      params[:to] = ['any@example.com', 'thing@example.com', "#{event.code}@example.com"]
      email = Griddler::Email.new(params.merge(from: organizer.person.email))
      allow(EmailInvalidCodeBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(EmailInvalidCodeBounceJob).not_to have_received(:perform_later)
    end

    it 'bounces email if none of multiple recipients is valid' do
      params[:to] = ['any@example.com', 'thing@example.com', 'foo@bar.com']
      allow(EmailInvalidCodeBounceJob).to receive(:perform_later)
      EmailProcessor.new(Griddler::Email.new(params)).process
      expect(EmailInvalidCodeBounceJob).to have_received(:perform_later)
    end

    it 'does not bounce email if valid address is in the Cc: field' do
      params.merge!(cc: ["#{event.code}@example.com", 'foo@bar.com'])
      email = Griddler::Email.new(params.merge(from: organizer.person.email))
      allow(EmailInvalidCodeBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(EmailInvalidCodeBounceJob).not_to have_received(:perform_later)
    end

    it 'does not bounce email if valid address is in the Bcc: field' do
      params.merge!(bcc: ["#{event.code}@example.com", 'foo@bar.com'])
      email = Griddler::Email.new(params.merge(from: organizer.person.email))
      allow(EmailInvalidCodeBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(EmailInvalidCodeBounceJob).not_to have_received(:perform_later)
    end

    it 'does not bounce email if recipient contains =' do # Outlook bug
      params[:to] = ['webmaster=webmaster@example.com']
      params[:recipient] = 'webmaster=webmaster@example.com'
      email = Griddler::Email.new(params)
      allow(EmailInvalidCodeBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(EmailInvalidCodeBounceJob).not_to have_received(:perform_later)
    end

    it 'does not bounce email if recipient address is angle bracketed' do
      params[:to] = ["<#{event.code}@example.com>"]
      params[:recipient] = "<#{event.code}@example.com>"
      email = Griddler::Email.new(params)
      allow(EmailInvalidCodeBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(EmailInvalidCodeBounceJob).not_to have_received(:perform_later)
    end
  end

  context 'validates subject' do
    context 'does not send message if subject contains' do
      before do
        maillist = double('EventMaillist')
        expect(maillist).not_to receive(:send_message)
        allow(EventMaillist).to receive(:new).and_return(maillist)
      end

      it 'Out of Office' do
        params[:subject] = "Re: Out of Office"
        email = Griddler::Email.new(params)
        EmailProcessor.new(email).process
        expect(EventMaillist).not_to have_received(:new)
      end

      it 'Bounce notice' do
        params[:subject] = "[Bounce notice]"
        email = Griddler::Email.new(params)
        EmailProcessor.new(email).process
        expect(EventMaillist).not_to have_received(:new)
      end

      it 'Vacation Notice' do
        params[:subject] = "Vacation Notice"
        email = Griddler::Email.new(params)
        EmailProcessor.new(email).process
        expect(EventMaillist).not_to have_received(:new)
      end

      it 'Away notice' do
        params[:subject] = "Re: Away notice"
        email = Griddler::Email.new(params)
        EmailProcessor.new(email).process
        expect(EventMaillist).not_to have_received(:new)
      end

      it 'Automatic reply' do
        params[:subject] = "Automatic reply: #{params[:subject]}"
        email = Griddler::Email.new(params)
        EmailProcessor.new(email).process
        expect(EventMaillist).not_to have_received(:new)
      end
    end
  end


  context 'validates Message-Id' do
    it "does not send workshop maillist message if it has already been sent" do
      message_id = 'b901cee7-e49a-4330-9ee2-3fc28c6343cb@domain.edu'
      params[:headers] = {'Message-Id' => message_id}
      params[:to] = ["#{event.code}@example.com"]
      params[:from] = organizer.person.email

      ActionMailer::Base.deliveries.clear
      allow(MaillistMailer).to receive(:workshop_maillist).and_call_original
      EmailProcessor.new(Griddler::Email.new(params)).process
      expect(MaillistMailer).to have_received(:workshop_maillist)
      expect(ActionMailer::Base.deliveries.count).to eq 1

      message_record = Sentmail.find_by_message_id(message_id)
      expect(message_record).not_to be_nil

      allow(EventMaillist).to receive(:new)
      EmailProcessor.new(Griddler::Email.new(params)).process
      expect(EventMaillist).not_to have_received(:new)
    end

    it "does not send workshop organizer maillist message more than once" do
      message_id = 'saA3H-4330-9ee2-7y4flasd025@domain.edu'
      params[:headers] = {'Message-Id' => message_id}
      params[:to] = ["#{event.code}-organizers@example.com"]
      membership.attendance = 'Confirmed'
      membership.save
      params[:from] = membership.person.email

      ActionMailer::Base.deliveries.clear
      allow(MaillistMailer).to receive(:workshop_organizers).and_call_original
      EmailProcessor.new(Griddler::Email.new(params)).process
      expect(MaillistMailer).to have_received(:workshop_organizers)
      expect(ActionMailer::Base.deliveries.count).to eq 1

      message_record = Sentmail.find_by_message_id(message_id)
      expect(message_record).not_to be_nil

      allow(EventMaillist).to receive(:new)
      EmailProcessor.new(Griddler::Email.new(params)).process
      expect(EventMaillist).not_to have_received(:new)
    end
  end


  context 'validates sender' do
    before do
      params[:to] = ["#{event.code}@example.com"]
    end

    it 'sends bounce email if sender has no Person record' do
      email = Griddler::Email.new(params)
      allow(EmailFromNonmemberBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(EmailFromNonmemberBounceJob).to have_received(:perform_later)
    end

    it 'sends bounce email if sender is not an event member' do
      params[:from] = "#{person.name} <#{person.email}>"
      email = Griddler::Email.new(params)
      allow(EmailFromNonmemberBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(EmailFromNonmemberBounceJob).to have_received(:perform_later)
    end

    it 'sends bounce email if sender is a non-confirmed member of event' do
      membership.person = person
      membership.attendance = 'Not Yet Invited'
      membership.save

      email = Griddler::Email.new(params)
      allow(EmailFromNonmemberBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(EmailFromNonmemberBounceJob).to have_received(:perform_later)
    end

    it 'does not bounce email if sender is a confirmed member of the event' do
      params[:from] = "#{person.name} <#{person.email}>"
      membership.person = person
      membership.attendance = 'Confirmed'
      membership.save

      email = Griddler::Email.new(params)
      allow(EmailFromNonmemberBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(EmailFromNonmemberBounceJob).not_to have_received(:perform_later)
    end

    it 'sends bounce email if non-organizer sends to unauthorized sub-group' do
      params[:from] = "#{person.name} <#{person.email}>"
      membership.person = person
      membership.attendance = 'Confirmed'
      membership.save
      params[:to] = ["#{event.code}-declined@example.com"]
      email = Griddler::Email.new(params)
      allow(UnauthorizedSubgroupBounceJob).to receive(:perform_later)

      EmailProcessor.new(email).process
      expect(UnauthorizedSubgroupBounceJob).to have_received(:perform_later).once

      params[:to] = ["#{event.code}-speakers@example.com"]
      email = Griddler::Email.new(params)
      EmailProcessor.new(email).process
      expect(UnauthorizedSubgroupBounceJob).to have_received(:perform_later).twice
    end

    it 'does not bounce email if non-organizer sends to authorized sub-group' do
      params[:from] = "#{person.name} <#{person.email}>"
      membership.person = person
      membership.attendance = 'Confirmed'
      membership.save
      params[:to] = ["#{event.code}@example.com"]
      email = Griddler::Email.new(params)
      allow(UnauthorizedSubgroupBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(UnauthorizedSubgroupBounceJob).not_to have_received(:perform_later)
    end

    it 'does not bounce email if sender is an organizer, even if Declined' do
      member = organizer
      params[:from] = "#{member.person.name} <#{member.person.email}>"
      member.attendance = 'Declined'
      member.save

      email = Griddler::Email.new(params)
      allow(EmailFromNonmemberBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(EmailFromNonmemberBounceJob).not_to have_received(:perform_later)
    end

    it 'does not bounce email if sender is a staff user for event.location' do
      staff_person = create(:person)
      create(:user, person: staff_person, role: 'staff', location: event.location)
      params[:from] = %Q("#{staff_person.name}" <#{staff_person.email}>)

      email = Griddler::Email.new(params)
      allow(EmailFromNonmemberBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(EmailFromNonmemberBounceJob).not_to have_received(:perform_later)
    end

    it 'sends bounce email if sender is staff with location other than event' do
      staff_person = create(:person)
      create(:user, person: staff_person, role: 'staff', location: 'nope')
      params[:from] = %Q("#{staff_person.name}" <#{staff_person.email}>)

      email = Griddler::Email.new(params)
      allow(EmailFromNonmemberBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(EmailFromNonmemberBounceJob).to have_received(:perform_later)
    end

    it 'does not bounce email if sender is a admin user, regardless of location' do
      admin_person = create(:person)
      create(:user, person: admin_person, role: 'admin', location: 'nope')
      params[:from] = %Q("#{admin_person.name}" <#{admin_person.email}>)

      email = Griddler::Email.new(params)
      allow(EmailFromNonmemberBounceJob).to receive(:perform_later)
      EmailProcessor.new(email).process
      expect(EmailFromNonmemberBounceJob).not_to have_received(:perform_later)
    end

    it 'sends report to sysadmin if sender has invalid email address' do
      params[:from] = 'invalid-email@foo'
      email = Griddler::Email.new(params)
      mailer = double('StaffMailer')
      # once for invalid email, another for not being a valid sender
      expect(mailer).to receive(:deliver_now).twice
      allow(StaffMailer).to receive(:notify_sysadmin).and_return(mailer)

      EmailProcessor.new(email).process
      expect(StaffMailer).to have_received(:notify_sysadmin).twice
    end
  end


  context '.process delivers email to maillist' do
    let(:email) { Griddler::Email.new(params) }
    let(:subgroup) { nil }
    let(:list_params) do
      {
        event: event,
        group: group,
        subgroup: subgroup,
        destination: destination
      }
    end
    let(:destination) { params[:to].first }

    before do
      maillist = double('EventMaillist')
      expect(maillist).to receive(:send_message).at_least(:once)
      allow(EventMaillist).to receive(:new).and_return(maillist)

      membership.person = person
      membership.attendance = 'Confirmed'
      membership.save
      params[:from] = "#{person.name} <#{person.email}>"
      @event2 = create(:event)
    end

    after do
      EmailProcessor.new(email).process
    end

    context 'if sender and recipient are valid' do
      let(:group) { 'Confirmed' }

      before do
        params[:to] = ["#{event.code}@example.com"]
      end

      it('invokes EventMaillist') { expect(EventMaillist).to receive(:new).with(email, list_params) }
    end

    describe 'passing attendance status from recipient email to EventMaillist' do
      let(:group) { 'Not Yet Invited' }

      before do
        params[:to] = ["#{event.code}-not_yet_invited@example.com"]
        params[:from] = organizer.person.email
      end

      it { expect(EventMaillist).to receive(:new).with(email, list_params) }
    end

    describe '"orgs" group' do
      let(:group) { 'orgs' }

      before { params[:to] = ["#{event.code}-orgs@example.com"] }

      it { expect(EventMaillist).to receive(:new).with(email, list_params) }
    end

    describe '"speakers" group' do
      let(:group) { 'speakers' }

      before do
        params[:to] = ["#{event.code}-speakers@example.com"]
        params[:from] = "#{organizer.person.name} <#{organizer.person.email}>"
      end

      it { expect(EventMaillist).to receive(:new).with(email, list_params) }
    end

    describe '"all" group' do
      let(:group) { 'all' }

      before do
        params[:to] = ["#{event.code}-all@example.com"]
        params[:from] = organizer.person.email
      end

      it { expect(EventMaillist).to receive(:new).with(email, list_params) }
    end

    context 'when in person group' do
      let(:subgroup) { 'in_person' }

      before do
        params[:to] = ["#{event.code}-#{group_from_email}@example.com"]
        params[:from] = organizer.person.email
      end

      context 'when confirmed' do
        let(:group) { 'Confirmed' }
        let(:group_from_email) { 'in_person' }

        it { expect(EventMaillist).to receive(:new).with(email, list_params) }
      end

      context 'when invited' do
        let(:group) { 'Invited' }
        let(:group_from_email) { 'invited-in_person' }

        it { expect(EventMaillist).to receive(:new).with(email, list_params) }
      end

      context 'when not yet invited' do
        let(:group) { 'Not Yet Invited' }
        let(:group_from_email) { 'not_yet_invited-in_person' }

        it { expect(EventMaillist).to receive(:new).with(email, list_params) }
      end
    end

    context 'when online group' do
      let(:subgroup) { 'online' }

      before do
        params[:to] = ["#{event.code}-#{group_from_email}@example.com"]
        params[:from] = organizer.person.email
      end

      context 'when confirmed' do
        let(:group) { 'Confirmed' }
        let(:group_from_email) { 'online' }

        it { expect(EventMaillist).to receive(:new).with(email, list_params) }
      end

      context 'when invited' do
        let(:group) { 'Invited' }
        let(:group_from_email) { 'invited-online' }

        it { expect(EventMaillist).to receive(:new).with(email, list_params) }
      end

      context 'when not yet invited' do
        let(:group) { 'Not Yet Invited' }
        let(:group_from_email) { 'not_yet_invited-online' }

        it { expect(EventMaillist).to receive(:new).with(email, list_params) }
      end
    end

    describe 'invoking EventMaillist once for each event in the To: field' do
      before do
        create(:membership, event: @event2, person: person)
        params[:to] = %W[#{event.code}@example.com #{@event2.code}@example.com]
      end

      it { expect(EventMaillist).to receive(:new).exactly(2).times }
    end

    describe 'invoking EventMaillist once for each event in the Cc: field' do
      before do
        create(:membership, event: @event2, person: person)
        params[:to] = ['myfriend@example.com']
        params[:cc] = %W[#{event.code}@example.com #{@event2.code}@example.com]
      end

      it { expect(EventMaillist).to receive(:new).exactly(2).times }
    end

    context 'when sender is confirmed for one event in To: but not another' do
      before { params[:to] = %W[#{event.code}@example.com #{@event2.code}@example.com] }

      after { allow(EmailFromNonmemberBounceJob).to receive(:perform_later) }

      it 'invokes EventMaillist once and EmailFromNonmemberBounceJob once' do
        expect(EventMaillist).to receive(:new).exactly(1).times
        expect(EmailFromNonmemberBounceJob).to receive(:perform_later).exactly(1).times
      end
    end

    describe 'handling comma-separated emails in the recipient field' do
      before do
        params[:to] = ["#{event.code}@example.com"]
        create(:membership, person: person, event: @event2, attendance: 'Confirmed')
        params[:recipient] = "#{event.code}-orgs@example.com, #{@event2.code}@example.com"
      end

      after { allow(EmailFromNonmemberBounceJob).to receive(:perform_later) }

      it 'works' do
        expect(EventMaillist).to receive(:new).exactly(3).times
        expect(EmailFromNonmemberBounceJob).not_to receive(:perform_later)
      end
    end
  end
end
