# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'rails_helper'

RSpec.shared_examples 'email invitation job' do
  it 'calls on the InvitationMailer' do
    described_class.new.perform(membership.id)

    expect(InvitationMailer).to have_received(:invite).with(invitation)
  end
end

RSpec.describe EmailInvitationJob, type: :job do
  describe '#perform' do
    let(:invitation) { double('invitation', id: 9) }
    let(:membership) { create(:membership, attendance: 'Not Yet Invited') }

    before do
      allow(invitation).to receive(:membership).and_return(membership)
      allow(Invitation).to receive(:find_by_id).and_return(invitation)
      allow(InvitationMailer).to receive_message_chain(:invite, :deliver_now)
    end

    context 'when called with initial_email: true' do
      it 'updaters membership attendance to Invited' do
        described_class.new.perform(1, initial_email: true)

        expect(membership.attendance).to eq 'Invited'
      end

      it_behaves_like 'email invitation job'
    end

    context 'when called with initial_email: false' do
      it 'does not update membership attendance' do
        described_class.new.perform(1, initial_email: false)

        expect(membership.attendance).to eq 'Not Yet Invited'
      end

      it_behaves_like 'email invitation job'
    end
  end

  describe '.perform_later' do
    it 'adds the job to the queue :urgent' do
      allow(InvitationMailer).to receive_message_chain(:invite, :deliver_now)

      described_class.perform_later(1)

      expect(enqueued_jobs.last[:job]).to eq described_class
    end
  end
end
