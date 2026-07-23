# Rails 7.1's ActionMailer::LogSubscriber declares
# `subscribe_log_level :deliver, :debug`, so the entire "Sent mail" delivery
# log line is silenced unless config.action_mailer.logger is at DEBUG.
# We can't raise mailer.log to DEBUG: at that level ActionMailer also logs
# the full raw message, including attachments, which we deliberately avoid
# dumping to log/mailer.log. Instead, register a Mail delivery observer that
# writes its own single INFO audit line per delivery, independent of the
# LogSubscriber's level gate.
class MailerAuditLogObserver
  def self.delivered_email(message)
    logger = ActionMailer::Base.logger
    return unless logger

    recipients = Array(message.to).join(', ')
    logger.info("Sent mail to #{recipients}, Subject: #{message.subject}, " \
                "on #{Time.current}")
  rescue StandardError
    nil
  end
end

ActiveSupport.on_load(:action_mailer) do
  Mail.register_observer(MailerAuditLogObserver)
end
