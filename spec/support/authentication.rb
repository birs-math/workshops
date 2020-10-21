
# Include inside before loop
def authenticate_user(person = nil, role = 'admin')
  person ||= FactoryBot.create(:person)
  @person = person
  @user = FactoryBot.create(:user, person: @person, role: role)
  login_as @user, scope: :user
  @user
end

def authenticate_for_controllers
  @person = FactoryBot.create(:person)
  @user = FactoryBot.create(:user, person: @person)
  @event = FactoryBot.create(:event)
  @membership = FactoryBot.create(:membership, event: @event, person: @person, attendance: 'Confirmed')
  sign_in @user
end

# to logout: logout(@user)

# Set the referring page
# Capybara.current_session.driver.header 'Referer', root_path
