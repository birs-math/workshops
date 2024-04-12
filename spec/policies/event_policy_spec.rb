# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'rails_helper'

describe 'EventPolicy' do
  before do
    @location = Setting.Locations.keys.first
  end

  subject { EventPolicy }

  let (:normal_user) { build_stubbed :user }
  let (:staff_user) { build_stubbed :user, :staff }
  let (:admin_user) { build_stubbed :user, :admin }

  permissions :edit? do
    (Event.states.keys - ['active']).each do |state|
      context "when event has #{state} state" do
        it 'does not allow normal users to edit events' do
          allow(normal_user).to receive(:is_organizer?).and_return(false)
          expect(subject).not_to permit(normal_user, Event.new(state: state))
        end

        it 'does not allow staff to edit events in different location' do
          staff_user.location = 'foo'
          event = create(:event, location: 'bar', state: state)
          expect(subject).not_to permit(staff_user, event)
        end

        it 'allows staff to edit events in same location' do
          staff_user.location = 'foo'
          event = create(:event, location: 'foo', state: state)
          expect(subject).to permit(staff_user, event)
        end

        it 'allows staff to edit template events' do
          allow(staff_user).to receive(:is_organizer?).and_return(false)
          event = Event.new(template: true, location: @location, state: state)
          expect(subject).to permit(staff_user, event)
        end

        it 'allows organizers to edit their events' do
          allow(normal_user).to receive(:is_organizer?).and_return(true)
          expect(subject).not_to permit(normal_user, Event.new(state: state))
        end

        it 'allows admins to edit events' do
          allow(admin_user).to receive(:is_organizer?).and_return(false)
          expect(subject).to permit(admin_user, Event.new(state: state))
        end
      end

      context 'when event has active state' do
        it 'does not allow normal users to edit events' do
          allow(normal_user).to receive(:is_organizer?).and_return(false)
          expect(subject).not_to permit(normal_user, Event.new(state: state))
        end

        it 'does not allow staff to edit events in different location' do
          staff_user.location = 'foo'
          event = create(:event, location: 'bar', state: :active)
          expect(subject).not_to permit(staff_user, event)
        end

        it 'allows staff to edit events in same location' do
          staff_user.location = 'foo'
          event = create(:event, location: 'foo', state: :active)
          expect(subject).to permit(staff_user, event)
        end

        it 'allows staff to edit template events' do
          allow(staff_user).to receive(:is_organizer?).and_return(false)
          event = Event.new(template: true, location: @location, state: :active)
          expect(subject).to permit(staff_user, event)
        end

        it 'allows organizers to edit their events' do
          allow(normal_user).to receive(:is_organizer?).and_return(true)
          expect(subject).to permit(normal_user, Event.new(state: :active))
        end

        it 'allows admins to edit events' do
          allow(admin_user).to receive(:is_organizer?).and_return(false)
          expect(subject).to permit(admin_user, Event.new(state: :active))
        end
      end
    end

  end

  permissions :update? do
    (Event.states.keys - ['active']).each do |state|
      context "when event has #{state} state" do
        it 'does not allow normal users to update events' do
          allow(normal_user).to receive(:is_organizer?).and_return(false)
          expect(subject).not_to permit(normal_user, Event.new(state: state))
        end

        it 'does not allow staff users to update events in different location' do
          staff_user.location = 'foo'
          event = create(:event, location: 'bar', state: state)
          allow(staff_user).to receive(:is_organizer?).and_return(false)
          expect(subject).not_to permit(staff_user, event)
        end

        it 'allows staff to edit events in same location' do
          staff_user.location = 'foo'
          event = create(:event, location: 'foo', state: state)
          expect(subject).to permit(staff_user, event)
        end

        it 'allows staff to update template events' do
          allow(staff_user).to receive(:is_organizer?).and_return(false)
          expect(subject).to permit(staff_user, Event.new(template: true,
                                                          location: @location,
                                                          state: state))
        end

        it 'allows organizers to edit their events' do
          allow(normal_user).to receive(:is_organizer?).and_return(true)
          expect(subject).not_to permit(normal_user, Event.new(state: state))
        end

        it 'allows admins to update events' do
          allow(admin_user).to receive(:is_organizer?).and_return(false)
          expect(subject).to permit(admin_user, Event.new(state: state))
        end
      end
    end

    context 'when event has active state' do
      it 'does not allow normal users to update events' do
        allow(normal_user).to receive(:is_organizer?).and_return(false)
        expect(subject).not_to permit(normal_user, Event.new(state: :active))
      end

      it 'does not allow staff users to update events in different location' do
        staff_user.location = 'foo'
        event = create(:event, location: 'bar')
        allow(staff_user).to receive(:is_organizer?).and_return(false)
        expect(subject).not_to permit(staff_user, event)
      end

      it 'allows staff to edit events in same location' do
        staff_user.location = 'foo'
        event = create(:event, location: 'foo')
        expect(subject).to permit(staff_user, event)
      end

      it 'allows staff to update template events' do
        allow(staff_user).to receive(:is_organizer?).and_return(false)
        expect(subject).to permit(staff_user, Event.new(template: true,
                                                        location: @location,
                                                        state: :active))
      end

      it 'allows organizers to edit their events' do
        allow(normal_user).to receive(:is_organizer?).and_return(true)
        expect(subject).to permit(normal_user, Event.new(state: :active))
      end

      it 'allows admins to update events' do
        allow(admin_user).to receive(:is_organizer?).and_return(false)
        expect(subject).to permit(admin_user, Event.new(state: :active))
      end
    end
  end

  permissions :new? do
    it 'allows only admins to start new events' do
      expect(subject).not_to permit(normal_user, Event.new)
      expect(subject).not_to permit(staff_user, Event.new)
      expect(subject).to permit(admin_user, Event.new)
    end

    it 'allows only admins to start new template events' do
      expect(subject).not_to permit(normal_user, Event.new(template: true))
      expect(subject).not_to permit(staff_user, Event.new(template: true))
      expect(subject).to permit(admin_user, Event.new(template: true))
    end
  end

  permissions :create? do
    it 'allows only admins to create new events' do
      expect(subject).not_to permit(normal_user, Event.new)
      expect(subject).not_to permit(staff_user, Event.new)
      expect(subject).to permit(admin_user, Event.new)
    end

    it 'allows only admins to create new template events' do
      expect(subject).not_to permit(normal_user, Event.new(template: true))
      expect(subject).not_to permit(staff_user, Event.new(template: true))
      expect(subject).to permit(admin_user, Event.new(template: true))
    end
  end

  permissions :destroy? do
    it 'allows only admins to destroy normal events' do
      expect(subject).not_to permit(normal_user, Event.new)
      expect(subject).not_to permit(staff_user, Event.new)
      expect(subject).to permit(admin_user, Event.new)
    end

    it 'allows only admins to destroy template events' do
      expect(subject).not_to permit(normal_user, Event.new(template: true))
      expect(subject).not_to permit(staff_user, Event.new(template: true))
      expect(subject).to permit(admin_user, Event.new(template: true))
    end
  end

  permissions :show? do
    context 'when event is imported' do
      let(:organizer_user) { build_stubbed :user }
      before do
        allow(normal_user).to receive(:is_organizer?).and_return(false)
        allow(staff_user).to receive(:is_organizer?).and_return(false)
        allow(admin_user).to receive(:is_organizer?).and_return(false)
        allow(organizer_user).to receive(:is_organizer?).and_return(true)
      end

      it 'does not allow normal users to view imported events' do
        expect(subject).not_to permit(normal_user, Event.new(state: :imported))
      end

      it 'does not allow staff users to view imported events' do
        expect(subject).not_to permit(staff_user, Event.new(state: :imported))
      end

      it 'allows admins to view imported events' do
        expect(subject).to permit(admin_user, Event.new(state: :imported))
      end

      it 'allows organizers to view imported events' do
        expect(subject).to permit(organizer_user, Event.new(state: :imported))
      end
    end

    it 'does not allow normal users to view template events' do
      expect(subject).not_to permit(normal_user, Event.new(template: true))
    end

    it 'allows staff and admin users to view template events' do
      expect(subject).to permit(staff_user, Event.new(template: true, location: @location))
      expect(subject).to permit(admin_user, Event.new(template: true))
    end
  end


  describe 'EventPolicy Scope' do
    before do
      10.upto(20) do |n|
        create(:event, code: "15w50#{n}")
      end
      @template = Event.first
      @template.template = true
      @template.save
    end

    let(:scope) { Event.all }
    subject(:policy_scope) { EventPolicy::Scope.new(user, scope).resolve }

    permissions '.scope' do
      context 'for a normal user' do
        let(:user) { normal_user }
        it 'removes template events from event listing' do
          expect(policy_scope).not_to include(@template)
        end
      end

      context 'for a staff user' do
        let(:user) { staff_user }
        it 'includes template events in event listing' do
          expect(policy_scope).to include(@template)
        end
      end

      context 'for an admin user' do
        let(:user) { admin_user }
        it 'includes template events in event listing' do
          expect(policy_scope).to include(@template)
        end
      end

    end
  end

end
