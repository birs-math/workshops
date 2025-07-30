# Copyright (c) 2025 Banff International Research Station
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

class ExpiredInvitationMailer < ApplicationMailer
  def notify(membership, expiry_date)
    @membership = membership
    @person = membership.person
    @event = membership.event
    @expiry_date = expiry_date
    @organization = GetSetting.org_name(@event.location)
    @program_coordinator = GetSetting.email(@event.location, 'program_coordinator')

    from_email = GetSetting.email(@event.location, 'rsvp')
    subject = "[#{@event.code}] Your invitation has expired"
    to_email = set_recipient(@person)

    mail(to: to_email,
         from: from_email,
         subject: subject)
  end
  
  private
  
  def set_recipient(person)
    recipient = '"' + person.name + '" <' + person.email + '>'
    if Rails.env.development? || ENV['APPLICATION_HOST'].include?('staging')
      recipient = GetSetting.site_email('webmaster_email')
    end
    recipient
  end
end
