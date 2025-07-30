# spec/factories/invitations.rb
FactoryBot.define do
  factory :invitation do
    association :membership
    invited_by { association :person }
    code { SecureRandom.urlsafe_base64(37) }
    
    # Add default values for required relationships
    before(:create) do |invitation|
      # Ensure membership and event exist
      if invitation.membership.nil?
        invitation.membership = create(:membership)
      end
      
      # Ensure invited_by is a Person object
      if invitation.invited_by.nil? || !invitation.invited_by.is_a?(Person)
        invitation.invited_by = create(:person)
      end
    end
  end
end