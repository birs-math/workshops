# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutomatedEmailPolicy do
  describe '.enabled?' do
    after { ENV.delete(described_class::ENV_FLAG) }

    it 'is true when ENABLE_AUTOMATED_EVENT_EMAILS=true' do
      ENV[described_class::ENV_FLAG] = 'true'
      expect(described_class.enabled?).to be true
    end

    it 'is false when explicitly set to false' do
      ENV[described_class::ENV_FLAG] = 'false'
      expect(described_class.enabled?).to be false
    end

    # The whole point: with no flag set, production must NOT send automated emails
    # (BIRS is holding all 2026/2027 workshops).
    it 'defaults to suppressed in production when the flag is unset' do
      ENV.delete(described_class::ENV_FLAG)
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      expect(described_class.enabled?).to be false
    end
  end
end
