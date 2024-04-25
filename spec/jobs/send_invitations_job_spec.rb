require 'rails_helper'

RSpec.describe SendInvitationsJob, type: :job do
  let(:event) { create(:event) }
  let(:user) { create(:user) }
  subject(:job) { SendInvitationsJob.perform_later(event_id: event.id, invited_by: user.id) }

  before do
    create(:membership, event: event, attendance: 'Not Yet Invited')
  end

  it 'queues the job' do
    expect { job }
      .to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
  end

  it 'is in urgent queue' do
    expect(SendInvitationsJob.new.queue_name).to eq('urgent')
  end

  it 'executes perform' do
    expect_any_instance_of(Invitation).to receive(:send_invite)
    perform_enqueued_jobs { job }
  end
end
