# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'rails_helper'

# The automated video system sends its API key in the body of every request to
# /api/v1/lectures.json. Until these filters were added the key was written to
# the production log in plaintext, so anyone with log access -- or any error
# reporter capturing request context -- had the credential.
describe 'log parameter filtering' do
  let(:filter) do
    ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
  end

  it 'filters the video system API key out of logged parameters' do
    logged = filter.filter('api_key' => 'MRIQ0ITjn5HmGjJQ', 'lecture_id' => 46_713)

    expect(logged['api_key']).to eq('[FILTERED]')
    expect(logged['lecture_id']).to eq(46_713),
                                    'non-sensitive params must stay readable for debugging'
  end

  it 'filters passwords and Devise tokens' do
    logged = filter.filter(
      'password' => 'hunter2',
      'password_confirmation' => 'hunter2',
      'reset_password_token' => 'abc123',
      'confirmation_token' => 'def456'
    )

    expect(logged.values.uniq).to eq(['[FILTERED]'])
  end

  it 'filters nested parameters, which is how the video system sends them' do
    logged = filter.filter(
      'lecture' => { 'api_key' => 'MRIQ0ITjn5HmGjJQ', 'title' => 'A talk' }
    )

    expect(logged['lecture']['api_key']).to eq('[FILTERED]')
    expect(logged['lecture']['title']).to eq('A talk')
  end
end
