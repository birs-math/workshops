# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'rails_helper'

RSpec.describe User, type: :model do
  it 'has valid factory' do
    user = create(:user)
    expect(user).to be_valid
  end

  it 'requires an email address' do
    u = build(:user, email: '')
    expect(u.valid?).to be_falsey

    u.email = 'foo@bar.com'
    expect(u.valid?).to be_truthy
  end

  it 'requires a valid email address' do
    u = build(:user, email: 'bleh')
    expect(u.valid?).to be_falsey

    u.email = 'bleh@blah.edu'
    expect(u.valid?).to be_truthy
  end

  it 'requires a password' do
    u = build(:user, password: '')
    expect(u.valid?).to be_falsey
  end

  it 'requires a person association' do
    u = build(:user, person_id: '')
    expect(u.valid?).to be_falsey
  end

  it 'the person association works' do
    u = create(:user)
    expect(u.person.name).not_to be_nil
    expect(u.person.name).to match(/\w/)
  end

  it 'has a role' do
    u = create(:user)
    expect(u.role).to eq('member')
  end

  it 'sets a default role to member, if none assigned' do
    u = build(:user)
    user = User.create(u.attributes.delete(:role))
    expect(user.role).to eq('member')
  end

  it 'has a location' do
    u = create(:user)
    expect(u.location).not_to be_empty
  end

  it 'if role is staff, requires location' do
    u = build(:user, role: 'staff', location: '')
    expect(u).not_to be_valid

    u.location = 'FOO'
    expect(u).to be_valid
  end

  it 'if role is not staff, does not require a location' do
    u = build(:user, location: '')
    expect(u.role).not_to eq('staff')
    expect(u).to be_valid
  end

  describe 'role predicates' do
    it '#is_admin? true for admin' do
      expect(build(:user, :admin).is_admin?).to be true
    end

    it '#is_admin? true for super_admin' do
      expect(build(:user, :super_admin).is_admin?).to be true
    end

    it '#is_admin? false for staff' do
      expect(build(:user, :staff).is_admin?).to be false
    end

    it '#is_admin? false for member' do
      expect(build(:user).is_admin?).to be false
    end

    it '#is_staff? true for staff, admin, and super_admin' do
      expect(build(:user, :staff).is_staff?).to be true
      expect(build(:user, :admin).is_staff?).to be true
      expect(build(:user, :super_admin).is_staff?).to be true
    end

    it '#is_staff? false for member' do
      expect(build(:user).is_staff?).to be false
    end
  end

  describe 'event membership predicates' do
    let(:event) { create(:event, current: true) }
    let(:other_event) { create(:event, current: true) }
    let(:person) { create(:person) }
    let(:user) { create(:user, person: person) }

    describe '#is_organizer?' do
      it 'true when person has Organizer role' do
        create(:membership, person: person, event: event, role: 'Organizer')
        expect(user.is_organizer?(event)).to be true
      end

      it 'true when person has Contact Organizer role' do
        create(:membership, person: person, event: event, role: 'Contact Organizer')
        expect(user.is_organizer?(event)).to be true
      end

      it 'false when person has Participant role' do
        create(:membership, person: person, event: event, role: 'Participant')
        expect(user.is_organizer?(event)).to be false
      end

      it 'false when person is organizer on a different event' do
        create(:membership, person: person, event: other_event, role: 'Organizer')
        expect(user.is_organizer?(event)).to be false
      end

      it 'false when no membership exists' do
        expect(user.is_organizer?(event)).to be false
      end
    end

    describe '#is_member?' do
      %w[Confirmed Invited Undecided].each do |status|
        it "true when attendance is #{status}" do
          create(:membership, person: person, event: event, attendance: status)
          expect(user.is_member?(event)).to be true
        end
      end

      ['Declined', 'Not Yet Invited'].each do |status|
        it "false when attendance is #{status}" do
          create(:membership, person: person, event: event, attendance: status)
          expect(user.is_member?(event)).to be false
        end
      end

      it 'false when membership is for another event' do
        create(:membership, person: person, event: other_event, attendance: 'Confirmed')
        expect(user.is_member?(event)).to be false
      end

      it 'false when no membership exists' do
        expect(user.is_member?(event)).to be false
      end
    end

    describe '#is_confirmed_member?' do
      it 'true when attendance is Confirmed' do
        create(:membership, person: person, event: event, attendance: 'Confirmed')
        expect(user.is_confirmed_member?(event)).to be true
      end

      %w[Invited Undecided Declined].each do |status|
        it "false when attendance is #{status}" do
          create(:membership, person: person, event: event, attendance: status)
          expect(user.is_confirmed_member?(event)).to be false
        end
      end

      it 'false when confirmed on a different event' do
        create(:membership, person: person, event: other_event, attendance: 'Confirmed')
        expect(user.is_confirmed_member?(event)).to be false
      end

      it 'false when no membership exists' do
        expect(user.is_confirmed_member?(event)).to be false
      end
    end
  end
end
