# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

# Authenticates API access tokens
class Api::V1::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
  protect_from_forgery with: :null_session
  before_action :parse_request, :authenticate_user_from_token!
  respond_to :json

  private

  def authenticate_user_from_token!
    @authenticated = false
    unauthorized && return if @json['api_key'].blank?

    payload_type = @json.keys.last.pluralize.upcase
    local_api_key = Setting.Site["#{payload_type}_API_KEY"]
    unavailable && return if local_api_key.blank?

    if Devise.secure_compare(local_api_key, @json['api_key'])
      @authenticated = true
    else
      unauthorized
    end
  end

  def parse_request
    if request.request_method == 'GET' && action_name == 'todays_lectures'
      @json = request.headers.env
      @room = todays_lectures_params
      @json['lecture'] = 'payload type placeholder'
    else
      @json = JSON.parse(request.body.read)
    end
  end

  def unauthorized
    head :unauthorized
  end

  def unavailable
    head :service_unavailable
  end

  def todays_lectures_params
    params.require(:room)
  end
end
