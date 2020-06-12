# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'rails_helper'

# DefaultSchedule creates a default schedule template for events that have none
describe 'DefaultSchedule' do
  before do
    @event = create(:event, template: false)
    authenticate_user # sets @user & @person
    @user.member!
    @membership = create(:membership, event: @event, person: @person,
                                      role: 'Organizer')
  end

  it 'accepts event and user objects as a parameter' do
    DS = DefaultSchedule.new(@event, @user)
    expect(DS.class).to eq(DefaultSchedule)
  end

  context 'If there is NO Template Schedule in the database' do
    before do
      Event.where(template: true).destroy_all
      membership = @event.memberships.first
      expect(membership.role).to eq('Organizer')
    end

    it 'does not add any items to the event\'s schedule' do
      expect(DefaultSchedule.new(@event, @user).schedules).to be_empty
    end
  end

  context 'If there is a Template Schedule in the database' do
    before do
      @tevent = create(:event_with_schedule,
                       code: '15w0001',
                       name: 'Testing Schedule Template event',
                       event_type: @event.event_type,
                       start_date: '2015-01-04',
                       end_date: '2015-01-09',
                       template: true
      )
      @tevent.schedules.each do |s|
        s.staff_item = true
        s.save
      end
      @not_staff_item = @tevent.schedules.last
      @not_staff_item.staff_item = false
      @not_staff_item.save
    end

    context 'And the user IS an organizer of the event' do
      before do
        membership = @event.memberships.first
        expect(membership.role).to eq('Organizer')
      end

      context 'If the event has at least one schedule item' do
        before do
          item = build(:schedule, name: 'This one item', event_id: @event.id,
            start_time: (@event.start_date + 2.days).to_time.change({ hour: 9 }),
            end_time: (@event.start_date + 2.days).to_time.change({ hour: 10 })
          )
          @event.schedules.create(item.attributes)
        end

        it 'does not add any items to the event\'s schedule' do
          expect(@event.schedules.size).to eq(1)
          expect(DefaultSchedule.new(@event, @user).schedules.size).to eq(1)
        end
      end

      context 'If the event has no previously associated schedule items' do
        before(:each) do
          @event.schedules.delete_all
          expect(@tevent.schedules).not_to be_empty
          DefaultSchedule.new(@event, @user)
        end

        it 'copies schedule items from the template event' do
          expect(@event.schedules.count).to eq(@tevent.schedules.count)
        end

        it 'changes the template schedule dates to match the given event' do
          @tevent.schedules.each do |t_item|
            e_item = @event.schedules.detect { |i| i.name == t_item.name }
            expect(e_item.start_time.hour).to eq(t_item.start_time.hour)
            expect(e_item.start_time.min).to eq(t_item.start_time.min)
            expect(e_item.end_time.hour).to eq(t_item.end_time.hour)
            expect(e_item.end_time.min).to eq(t_item.end_time.min)
          end
        end

        it 'preserves the "staff_item" attribute for added items' do
          @event.schedules.each do |s|
            if s.name == @not_staff_item.name
              expect(s.staff_item).to be(false)
            else
              expect(s.staff_item).to be(true)
            end
          end
        end
      end

      context 'If the event has only "Default Schedule" items' do
        before do
          @event.schedules.delete_all
          item = build(:schedule, name: 'Default item', event_id: @event.id,
            start_time: (@event.start_date + 2.days).to_time
              .change(hour: 9),
            end_time: (@event.start_date + 2.days).to_time.change(hour: 10),
            updated_by: 'Default Schedule'
          )
          @event.schedules.create(item.attributes)
        end

        it 'reloads template event schedule' do
          expect(@event.schedules.count).to eq(1)
          DefaultSchedule.new(@event, @user)
          expect(@event.schedules.count).to eq(@tevent.schedules.count)
        end
      end
    end

    context 'And the user is NOT an organizer of the event' do
      before do
        membership = @event.memberships.first
        expect(membership.role).to eq('Organizer')
        membership.role = 'Participant'
        membership.save!
      end

      it 'does not copy template schedule items' do
        @event.schedules.delete_all
        expect(@event.memberships.first.role).to eq('Participant')
        expect(@event.schedules).to be_empty
        expect(@tevent.schedules).not_to be_empty

        DefaultSchedule.new(@event, @user)
        expect(@event.schedules).to be_empty
      end
    end
  end
end
