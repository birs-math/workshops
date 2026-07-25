# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'rails_helper'

# GET /events/:id.json used to return every confirmed participant's name and
# affiliation to anonymous callers, for workshops that had not yet taken place,
# while the equivalent HTML page required sign-in. Attendee lists for upcoming
# workshops are used to send participants fake hotel-booking mail, so the JSON
# must withhold what the HTML withholds.
describe 'GET /events/:id.json member privacy', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:allowed_ip) { EventsController::MEMBER_LIST_ALLOWED_IPS.first }

  before do
    @event = create(:event_with_members, start_date: Date.current + 30.days,
                                         end_date: Date.current + 35.days)
    @member = @event.memberships.where(attendance: 'Confirmed').first
    @member.update_columns(role: 'Participant') if @member
  end

  def members_in_response
    JSON.parse(response.body).fetch('members', nil)
  end

  context 'as an anonymous caller' do
    it 'returns the event but withholds the participant list' do
      get "/events/#{@event.code}.json"

      expect(response).to be_successful
      body = JSON.parse(response.body)
      expect(body['event']['code']).to eq(@event.code),
                                       'public event metadata must keep working'
      expect(body['members']).to eq([]),
                                 'confirmed participants must not be exposed anonymously'
    end

    it 'still exposes organizers, who are already public on www.birs.ca' do
      get "/events/#{@event.code}.json"

      expect(JSON.parse(response.body)['organizers']).to be_an(Array)
    end

    it 'keeps the members key present so existing consumers do not break' do
      get "/events/#{@event.code}.json"

      expect(JSON.parse(response.body)).to have_key('members')
    end
  end

  context 'as archytas2, the primary record holder' do
    # It polls this endpoint constantly. If it stopped receiving members we could
    # not rule out the empty list propagating as deletions in the primary DB.
    it 'receives the full participant list unchanged' do
      get "/events/#{@event.code}.json", headers: { 'REMOTE_ADDR' => allowed_ip }

      expect(response).to be_successful
      expect(members_in_response).not_to be_empty
    end
  end

  # This documents a real limitation rather than asserting a protection we do not
  # have. Rails on its own DOES trust X-Forwarded-For, so bare-Rails a forged
  # header wins. In production the allowlist holds only because nginx-proxy
  # appends the true client address and remote_ip takes the rightmost untrusted
  # entry -- verified against wstaging on 2026-07-25 with forged
  # X-Forwarded-For (single and chained), X-Real-IP, X-Client-IP and Forwarded,
  # all of which resolved to the real caller.
  #
  # The proxy is therefore load-bearing for this control. Anything that lets a
  # caller reach the app directly re-opens the exposure, which is why the API
  # token is the intended replacement rather than a nice-to-have.
  context 'source-address trust (documents the proxy dependency)' do
    it 'trusts X-Forwarded-For when no proxy has appended the real address' do
      get "/events/#{@event.code}.json",
          headers: { 'HTTP_X_FORWARDED_FOR' => allowed_ip, 'REMOTE_ADDR' => '203.0.113.9' }

      expect(members_in_response).not_to be_empty,
                                         'bare Rails trusts XFF; production safety depends on nginx-proxy'
    end

    it 'withholds the list when the rightmost address is untrusted, as nginx-proxy arranges' do
      get "/events/#{@event.code}.json",
          headers: { 'HTTP_X_FORWARDED_FOR' => "#{allowed_ip}, 203.0.113.9",
                     'REMOTE_ADDR' => '203.0.113.9' }

      expect(members_in_response).to eq([])
    end
  end

  context 'as a signed-in staff user' do
    it 'receives the participant list' do
      staff = create(:user, :staff, location: @event.location)
      sign_in staff

      get "/events/#{@event.code}.json"

      expect(members_in_response).not_to be_empty
    end
  end

  context 'as a signed-in user with no connection to the event' do
    it 'is treated like the public and gets nothing' do
      sign_in create(:user)

      get "/events/#{@event.code}.json"

      expect(members_in_response).to eq([])
    end
  end

  # The JSON view was written in 2016 with its own idea of who may see members.
  # The rule was then tightened on the HTML side between 2019 and 2025 and this
  # representation was never swept, which is how participant lists stayed public
  # for a decade. Both must now answer to one predicate; this fails if a future
  # change re-introduces a second copy of the rule.
  describe 'agreement with the HTML member list' do
    def json_shows_members?(user)
      user ? sign_in(user) : nil
      get "/events/#{@event.code}.json"
      result = !members_in_response.empty?
      sign_out(user) if user
      result
    end

    def html_would_show_members?(user)
      EventPolicy.new(user, @event).view_attendance_status?('Confirmed')
    end

    def organizer_user(event)
      person = create(:person)
      create(:membership, event: event, person: person, role: 'Organizer')
      create(:user, person: person, email: person.email)
    end

    def event_member_user(event)
      person = create(:person)
      create(:membership, event: event, person: person,
                          role: 'Participant', attendance: 'Confirmed')
      create(:user, person: person, email: person.email)
    end

    {
      'an organizer' => ->(e) { organizer_user(e) },
      'a confirmed member' => ->(e) { event_member_user(e) },
      'staff at the location' => ->(e) { create(:user, :staff, location: e.location) },
      'staff elsewhere' => ->(_e) { create(:user, :staff, location: 'Somewhere Else') },
      'an admin' => ->(_e) { create(:user, :admin) },
      'an unrelated member' => ->(_e) { create(:user) }
    }.each do |label, build_user|
      it "matches the HTML rule for #{label}" do
        user = instance_exec(@event, &build_user)

        expect(json_shows_members?(user)).to eq(html_would_show_members?(user)),
          "JSON and HTML disagree for #{label} -- the two representations have drifted again"
      end
    end
  end
end
