# frozen_string_literal: true

class AttendanceConfirmationMailerPreview < ActionMailer::Preview
  def remind
    AttendanceConfirmationMailer.remind(Invitation.last.id)
  end
end
