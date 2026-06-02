# frozen_string_literal: true

# Kill-switch for automated organizer/participant emails:
#   * event-statistics notices  (Que::ReportEventStatisticsJob -> EventStatisticsMailer)
#   * RSVP reminders / staff alerts (Que::DoubleCheckAttendanceJob -> AttendanceConfirmationMailer)
#
# BIRS is holding all 2026/2027 workshops (invites disabled), so these must NOT go
# out in production — they tell organizers to "issue new invites" they cannot send,
# which generates "why can't we invite?" questions to staff.
#
# Default: DISABLED (suppressed). Turn it on explicitly, per environment, with:
#   ENABLE_AUTOMATED_EVENT_EMAILS=true
# Set it in staging to exercise the mail path against MailHog; leave it unset/false
# in production until the hosting hold lifts and invites are re-enabled. Test env
# defaults enabled so existing mailer/job specs keep asserting the send path.
module AutomatedEmailPolicy
  ENV_FLAG = 'ENABLE_AUTOMATED_EVENT_EMAILS'

  def self.enabled?
    default = Rails.env.test? ? 'true' : 'false'
    ENV.fetch(ENV_FLAG, default).to_s.strip.downcase == 'true'
  end
end
