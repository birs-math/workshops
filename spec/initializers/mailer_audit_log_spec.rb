# frozen_string_literal: true

require 'rails_helper'

# Guards against the Rails 7.1 regression where ActionMailer::LogSubscriber's
# `subscribe_log_level :deliver, :debug` silences the built-in "Sent mail"
# line whenever the mailer logger is at INFO (as it is in production, to
# avoid dumping attachments at DEBUG). MailerAuditLogObserver must still
# leave an audit line in that case.
class MailerAuditLogTestMailer < ActionMailer::Base
  default from: 'sender@example.com'

  def test_email
    mail(to: 'recipient@example.com', subject: 'Audit Log Test', body: 'hello')
  end
end

RSpec.describe MailerAuditLogObserver do
  let(:log_io) { StringIO.new }

  around do |example|
    original_logger = ActionMailer::Base.logger
    original_delivery_method = ActionMailer::Base.delivery_method
    original_perform_deliveries = ActionMailer::Base.perform_deliveries

    ActionMailer::Base.logger = Logger.new(log_io).tap { |l| l.level = Logger::INFO }
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true

    example.run

    ActionMailer::Base.logger = original_logger
    ActionMailer::Base.delivery_method = original_delivery_method
    ActionMailer::Base.perform_deliveries = original_perform_deliveries
  end

  it 'writes an INFO audit line on delivery, even though the LogSubscriber deliver line is silenced' do
    MailerAuditLogTestMailer.test_email.deliver_now

    log_output = log_io.string
    expect(log_output).to include('Sent mail to recipient@example.com')
    expect(log_output).to include('Subject: Audit Log Test')
  end

  it 'does not raise when the mailer logger is nil' do
    ActionMailer::Base.logger = nil

    expect { MailerAuditLogTestMailer.test_email.deliver_now }.not_to raise_error
  end
end
