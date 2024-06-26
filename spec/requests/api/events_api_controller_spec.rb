# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'rails_helper'
require 'factory_bot_rails'

describe Api::V1::EventsController do
  before do
    @key = GetSetting.site_setting('EVENTS_API_KEY')
  end

  context '#create' do
    before do
      @event = build(:event)
      @payload = {
          api_key: @key,
          event: @event.as_json,
          memberships: [
            {
              "role": 'Participant',
              "person": build(:person).as_json
            },
            {
              "role": 'Organizer',
              "person": build(:person).as_json
            }
          ]
      }
    end

    it 'authenticates with the correct api key' do
      post '/api/v1/events.json', params: @payload.to_json
      expect(response).to be_successful
    end

    it 'does not authenticate with an invalid api key' do
      @payload['api_key'] = '123'
      post '/api/v1/events.json', params: @payload.to_json

      expect(response).to be_unauthorized
    end

    it 'given appropriate keys and event data, it creates an event' do
      post '/api/v1/events.json', params: @payload.to_json
      expect(response).to have_http_status(:created)
      expect(Event.find(@event.code)).not_to be_nil
    end

    it 'assigns max_observers to Settings.Location[location][max_observers]' do
      event = build(:event, max_observers: nil)
      @payload['event'] = event.as_json

      post '/api/v1/events.json', params: @payload.to_json

      event = Event.find(event.code)
      max = GetSetting.max_observers(event.location)
      expect(max).not_to be_blank
      expect(event.max_observers).to eq(max)
    end

    it 'assigns max_participants to Settings.Location[location][max_participants]' do
      event = build(:event, max_participants: nil)
      @payload['event'] = event.as_json

      post '/api/v1/events.json', params: @payload.to_json
      event = Event.find(event.code)
      max = GetSetting.max_participants(event.location)
      expect(max).not_to be_blank
      expect(event.max_participants).to eq(max)
    end

    it 'given invalid or missing event code, it fails' do
      event = build(:event, code: nil)
      @payload['event'] = event.as_json

      post '/api/v1/events.json', params: @payload.to_json
      expect(response).to be_bad_request
    end

    it 'given event code of existing event, it fails' do
      existing_event = create(:event)
      @payload['event'] = existing_event.as_json

      post '/api/v1/events.json', params: @payload.to_json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'given missing, invalid or empty event, it fails' do
      @payload['event'] = {}
      post '/api/v1/events.json', params: @payload.to_json
      expect(response).to have_http_status(:bad_request)

      @payload['event'] = Array.new
      post '/api/v1/events.json', params: @payload.to_json
      expect(response).to have_http_status(:bad_request)

      @payload.delete(:event)
      post '/api/v1/events.json', params: @payload.to_json
      expect(response).to have_http_status(:bad_request)
    end

    it 'saves custom fields' do
      event = build(:event)
      custom_field_attributes = build(:custom_field)
      @payload['event'] = event.attributes.merge(custom_fields_attributes: [custom_field_attributes]).as_json

      post '/api/v1/events.json', params: @payload.to_json
      event = Event.find(event.code)
      expect(event.custom_fields.size).to eq(1)
    end
  end

  context '#sync' do
    before do
      @event = create(:event_with_members)
      @payload = {
          api_key: @key,
          event_id: @event.code,
          event: ''
      }
    end

    it 'given invalid event_id, it fails' do
      @payload['event_id'] = 'foo'
      post '/api/v1/events/sync.json', params: @payload.to_json
      expect(response).to be_bad_request
    end
  end
end
