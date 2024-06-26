# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Que::DoubleCheckAttendanceJob, type: :job do

  subject { described_class.run(event_id: event.id) }

  let(:event) do
    create(
      :event,
      start_date: start_date,
      end_date: end_date,
      max_virtual: 10,
      max_participants: 10,
      event_format: format
    )
  end
  let(:start_date) { 3.month.since(Date.today) }
  let(:end_date) { start_date + 5.days }
  let(:format) { 'Hybrid' }

  def create_membership(role, attendance: 'Confirmed')
    create(:membership, role: role, attendance: attendance, event: event)
  end

  let(:participant_invitation) do
    create(:invitation, membership: create_membership('Participant'))
  end

  let(:organizer_invitation) do
    create(:invitation, membership: create_membership('Organizer'))
  end

  let(:contact_organizer_invitation) do
    create(:invitation, membership: create_membership('Contact Organizer'))
  end

  before do
    participant_invitation
    organizer_invitation
    contact_organizer_invitation
    create(:invitation, membership: create_membership('Virtual Participant'))
    create_membership('Participant')
    create(:invitation, membership: create_membership('Participant', attendance: 'Undecided'))
  end

  describe '.enqueue' do
    context 'when event is Online' do
      let(:format) { 'Online' }

      it 'does not send emails' do
        expect { subject }.not_to change { ActionMailer::Base.deliveries.count }
      end

      it 'does not schedule next step' do
        expect { subject }.not_to change { QueJobs.count }
      end
    end

    context 'when error' do
      before do
        allow(AttendanceConfirmationMailer).to receive(:remind).and_raise(ActiveRecord::RecordNotFound)
        allow(StaffMailer).to receive(:notify_sysadmin).and_call_original
      end

      it 'sends error report to sysadmin' do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)

        expect(StaffMailer).to have_received(:notify_sysadmin)
      end
    end

    describe 'step: :rsvp_one_month_before_event' do
      subject { described_class.run(event_id: event.id, step: :rsvp_one_month_before_event) }

      context 'when it is <= 2 weeks until workshop' do
        let(:start_date) { Date.today + 2.weeks }

        it('does not send email') { expect { subject }.not_to change { ActionMailer::Base.deliveries.count } }
      end

      context 'when it is > 2 weeks until event start' do
        let(:start_date) { Date.today + 3.weeks }

        it 'reminds confirmed members about upcoming workshop' do
          subject

          expect(ActionMailer::Base.deliveries.count).to eq(3)
        end
      end
    end

    describe 'step: :alert_staff' do
      subject { described_class.run(event_id: event.id, step: :alert_staff) }

      before do
        create(:user, :staff, location: event.location)
      end

      context 'when there are still members who did not RSVP' do
        it 'sends out email to staff' do
          allow(AttendanceConfirmationMailer).to receive(:alert_staff).and_call_original

          subject

          expect(AttendanceConfirmationMailer).to have_received(:alert_staff).with(event_id: event.id)
        end
      end

      context 'when all members RSVP' do
        before do
          participant_invitation.confirm_attendance
          organizer_invitation.confirm_attendance
          contact_organizer_invitation.confirm_attendance
        end

        it 'does not notify staff' do
          expect { subject }.not_to change { ActionMailer::Base.deliveries.count }
        end
      end
    end

    context 'when unknown step' do
      subject { described_class.run(event_id: event.id, step: :non_existing) }

      it 'sends email to sysadmin' do
        allow(StaffMailer).to receive(:notify_sysadmin).and_call_original

        subject

        expect(StaffMailer).to have_received(:notify_sysadmin)
      end
    end
  end
end
