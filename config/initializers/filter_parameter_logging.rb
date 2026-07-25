# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
#
# :api_key covers LECTURES_API_KEY / EVENTS_API_KEY, which the automated video
# system sends in the JSON body of every request. Without it the key was written
# to the production log in plaintext on every call -- roughly once a second while
# the video system retried a failure. :token catches Devise's password-reset and
# confirmation tokens, which are credentials for as long as they are valid.
#
# Filters match on substrings, so :api_key also covers "lecture_api_key" and the
# like. This affects logging only, never the values the application receives.
Rails.application.config.filter_parameters += [
  :password, :password_confirmation, :api_key, :token, :secret
]