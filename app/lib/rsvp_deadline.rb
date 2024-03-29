# ./app/lib/rsvp_deadline.rb
#
# Copyright (c) 2018 Banff International Research Station
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

# Calculates RSVP deadline for invitation emails
class RsvpDeadline
  def initialize(event, sent_on = DateTime.current, membership = false)
    @event = event
    @start_date = event.start_date_in_time_zone
    @end_date = event.end_date_in_time_zone
    @sent_on = sent_on.in_time_zone(event.time_zone)
    @membership = membership || Membership.new(role: 'Virtual Participant')
  end

  def rsvp_by
    rsvp_deadline = calculate_deadline
    if @event.online?
      rsvp_deadline = @end_date.change({hour: 23, minute: 59})
    end

    rsvp_deadline.strftime('%B %-d, %Y')
  end

  def calculate_deadline
    return @end_date if @event.online? || @membership.virtual?

    rsvp_deadline = (@sent_on + 4.weeks)
    today = DateTime.current
    if (@start_date - @sent_on).to_i < 10.days.to_i
      rsvp_deadline = @start_date.prev_occurring(:tuesday)
      rsvp_deadline = today + 1.day if rsvp_deadline < today
    elsif (@start_date - @sent_on).to_i < 2.month.to_i
      rsvp_deadline = (@sent_on + 10.days)
    elsif (@start_date - @sent_on).to_i < (3.months + 5.days).to_i
      rsvp_deadline = (@sent_on + 21.days)
    end
    rsvp_deadline
  end
end
