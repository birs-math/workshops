# ./spec/features/membership_add_spec.rb
#
# Copyright (c) 2019 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'rails_helper'

describe 'Invite Members', type: :feature do
  before do
    @event = create(:event_with_members)
    @event.start_date = (Date.current + 1.month).beginning_of_week(:sunday)
    @event.end_date = @event.start_date + 5.days
    @event.save
    organizer = @event.memberships.where("role='Contact Organizer'").first
    @org_user = create(:user, email: organizer.person.email,
                             person: organizer.person)
    @participant = @event.memberships.where("role='Participant'").first
    @user = create(:user)
  end

  describe 'Visibility of Invite Members link, access to page' do
    it 'hides from and denies access to public users' do
      visit event_memberships_path(@event)
      expect(page).not_to have_link("Invite Members")

      visit invite_event_memberships_path(@event)
      expect(current_path).to eq(user_session_path)
      expect(page).to have_text('You need to sign in')
    end

    it 'hides from non-member users' do
      login_as @user, scope: :user
      visit event_memberships_path(@event)
      expect(page).not_to have_link('Invite Members')

      visit invite_event_memberships_path(@event)
      expect(current_path).to eq(event_memberships_path(@event))
      expect(page).to have_text('Access denied')

      logout(@user)
    end

    it 'hides from member users' do
      @user.email = @participant.person.email
      @user.person = @participant.person
      @user.save

      login_as @user, scope: :user
      visit event_memberships_path(@event)
      expect(page).not_to have_link('Invite Members')

      visit invite_event_memberships_path(@event)
      expect(current_path).to eq(event_memberships_path(@event))
      expect(page).to have_text('Access denied')

      logout(@user)
    end

    it 'shows to and allows access to organizer users' do
      login_as @org_user, scope: :user
      visit event_memberships_path(@event)
      expect(page).to have_link("Invite Members")

      first(:link, "Invite Members").click
      expect(current_path).to eq(invite_event_memberships_path(@event))
      logout(@org_user)
    end

    it 'shows to and allows access to staff users' do
      @user.staff!
      login_as @user
      visit event_memberships_path(@event)
      expect(page.body).to have_link('Invite Members',
          href: invite_event_memberships_path(@event))

      first(:link, "Invite Members").click

      expect(current_path).to eq(invite_event_memberships_path(@event))
      logout(@user)
    end

    it 'shows to and allows access to admin users' do
      @user.admin!
      login_as @user
      visit event_memberships_path(@event)
      expect(page.body).to have_link('Invite Members',
          href: invite_event_memberships_path(@event))

      visit event_memberships_path(@event)
      expect(page.body).to have_link('Invite Members',
          href: invite_event_memberships_path(@event))
      first(:link, "Invite Members").click

      expect(current_path).to eq(invite_event_memberships_path(@event))
      logout(@user)
    end

    it 'hides and denies access if the event is in the past' do
      @event.start_date = (Date.current - 1.month).beginning_of_week(:sunday)
      @event.end_date = @event.start_date + 5.days
      @event.save
      @user.staff!
      login_as @org_user

      visit event_memberships_path(@event)
      expect(page).not_to have_link('Invite Members')

      visit invite_event_memberships_path(@event)
      expect(current_path).to eq(event_memberships_path(@event))
      expect(page).to have_text('Access denied')

      @event.start_date = (Date.current + 1.month).beginning_of_week(:sunday)
      @event.end_date = @event.start_date + 5.days
      @event.save
      logout(@org_user)
    end
  end

  describe 'Invite Members Page' do
    before do
      login_as @org_user, scope: :user
      visit invite_event_memberships_path(@event)
    end

    it 'groups members according to non-confirmed/declined attendance' do
      ['Not Yet Invited', 'Undecided', 'Invited'].each do |status|
        expect(page).to have_css(".card-title, .table-heading",
                                  text: "#{status} Members")
      end
      ['Confirmed', 'Declined'].each do |status|
        expect(page).not_to have_css(".card-title, .table-heading",
                                  text: "#{status} Members")
      end
    end

    it 'shows the "Reply-by" date' do
      expected_date = RsvpDeadline.new(@event, DateTime.current, @event.memberships.last)
                                  .calculate_deadline.strftime('%Y-%m-%d')
      expect(page).to have_text(expected_date)
    end

    context 'Physical events' do
      before do
        @event.update_columns(event_format: 'Physical')
        visit invite_event_memberships_path(@event)
      end

      it 'shows how many spots are left, given max participants' do
        spots_left = @event.max_participants - @event.num_invited_participants
        expect(page).to have_text("There are #{spots_left} spots left")
      end
    end

    context 'Online events' do
      before do
        @event.update_columns(event_format: 'Online')
        visit invite_event_memberships_path(@event)
      end

      it 'shows how many spots are left, given max_virtual participants' do
        spots_left = @event.max_virtual - @event.num_invited_participants
        expect(page).to have_text("There are #{spots_left} spots left")
      end
    end

    context 'Hybrid events' do
      before do
        @event.update_columns(event_format: 'Hybrid')
        visit invite_event_memberships_path(@event)
      end

      it 'shows how many Physical and Virtual spots are left, given settings' do
        max_physical = @event.max_participants
        physical_spots = max_physical - @event.num_invited_participants
        max_virtual = @event.max_virtual
        virtual_spots = max_virtual - @event.num_invited_virtual

        msg = "There are #{physical_spots}/#{max_physical} in-person spots, and
              #{virtual_spots}/#{max_virtual} virtual spots left".squish

        expect(page).to have_text(msg)
      end
    end


    it 'has checkboxes for each member listed' do
      ['Not Yet Invited', 'Undecided', 'Invited'].each do |status|
        @event.memberships.where(attendance: status).each do |member|
          html_id = 'invite_members_form_' + member.id.to_s
          expect(page).to have_css('input#' + html_id)
        end
      end
    end

    it 'has Invite and Send Reminder buttons for each attendance status' do
      expect(@event.num_attendance('Not Yet Invited')).to be > 0
      expect(page).to have_button(value: 'Invite Selected Members')
      expect(@event.num_attendance('Invited')).to be > 0
      expect(page).to have_button(value: 'Send Reminder to Selected Invited
        Members'.squish)
      expect(@event.num_attendance('Undecided')).to be > 0
      expect(page).to have_button(value: 'Send Reminder to Selected Undecided
        Members'.squish)
    end
  end

  describe 'Sending Invitations & Reminders' do
    before do
      5.times do
        create(:membership, event: @event, attendance: 'Not Yet Invited')
        create(:membership, event: @event, attendance: 'Invited')
      end
      login_as @org_user, scope: :user
      visit invite_event_memberships_path(@event)
    end

    it 'warns if no members selected' do
      click_button("not-yet-invited-submit")
      expect(current_path).to eq(invite_event_memberships_path(@event))
      expect(page).to have_text("No members selected to invite")
    end

    it 'sends invitations to selected members' do
      selected = []
      i = 1
      @event.memberships.where(role: 'Participant').where(attendance: 'Not Yet Invited').each do |m|
        if i.even?
          selected << m.id
          html_id = 'invite_members_form_' + m.id.to_s
          find(:css, "input##{html_id}").set(true)
        end
        i += 1
      end

      click_button('not-yet-invited-submit')

      selected.each do |id|
        membership = Membership.find(id)
        expect(EmailInvitationJob).to have_been_enqueued.with(membership.invitation.id, initial_email: true)
      end
    end

    it 'sends reminders to selected members, updates invite_reminders field' do
      selected = []
      i = 1
      @event.memberships.where(role: 'Participant')
                        .where(attendance: 'Invited').each do |member|

        expect(member.invite_reminders).to be_empty
        if i.odd?
          # an Invitation must already exist for a reminder to be sent
          Invitation.new(membership: member, invited_by: 'Rspec').send_invite
          selected << member.id
          html_id = 'invite_members_form_' + member.id.to_s
          find(:css, "input##{html_id}").set(true)
        end
        i += 1
      end

      click_button('Send Reminder to Selected Invited Members')

      selected.each do |id|
        reminders = Membership.find(id).invite_reminders
        expect(reminders).not_to be_empty
        expect(reminders.values.last).to eq(@org_user.person.name)
      end
    end

    context 'Physical events' do
      before do
        @event.update_columns(event_format: 'Physical')
        visit invite_event_memberships_path(@event)
      end

      it 'invitation fails if max_participants is exceeded' do
        num_participants = @event.num_invited_participants
        @event.max_participants = num_participants
        @event.save!

        participant = @event.memberships.where(role: 'Participant')
                                        .where(attendance: 'Not Yet Invited').last
        expect(participant).not_to be_blank
        html_id = 'invite_members_form_' + participant.id.to_s
        find(:css, "input##{html_id}").set(true)

        click_button('not-yet-invited-submit')

        updated_member = Membership.find(participant.id)
        expect(updated_member.attendance).to eq('Not Yet Invited')
        expect(page).to have_text("You may not invite more than
          #{@event.max_participants} participants.".squish)
        expect(current_path).to eq(invite_event_memberships_path(@event))
      end
    end

    context 'Online events' do
      before do
        @event.update_columns(event_format: 'Online')
        @event.memberships.select {|m| m.role == 'Participant'}.each do |member|
          member.update_columns(role: 'Virtual Participant')
        end

      end

      it 'invitation fails if max_virtual is exceeded' do
        num_participants = @event.num_invited_virtual
        @event.max_virtual = num_participants
        @event.save!

        visit invite_event_memberships_path(@event)

        participant = @event.memberships.where(role: 'Virtual Participant')
                            .where(attendance: 'Not Yet Invited').last
        expect(participant).not_to be_blank
        html_id = 'invite_members_form_' + participant.id.to_s
        find(:css, "input##{html_id}").set(true)

        click_button('not-yet-invited-submit')

        expect(current_path).to eq(invite_event_memberships_path(@event))
        updated_member = Membership.find(participant.id)
        expect(updated_member.attendance).to eq('Not Yet Invited')
        expect(page).to have_text("You may not invite more than
          #{@event.max_virtual} participants.".squish)
      end
    end

    context 'Hybrid events' do
      before do
        @event.update_columns(event_format: 'Hybrid')
        @event.memberships.select {|m| m.role == 'Participant' &&
          (m.attendance == 'Not Yet Invited' || m.attendance == 'Confirmed')}
              .each_slice(2) do |member|
          member[0].update_columns(role: 'Virtual Participant')
        end
      end

      it 'invitation fails if max_participants is exceeded by in-person
        participants'.squish do
        num_participants = @event.num_invited_in_person
        @event.max_participants = num_participants
        @event.save!

        visit invite_event_memberships_path(@event)

        participant = @event.memberships.where(role: 'Participant')
                            .where(attendance: 'Not Yet Invited').last
        expect(participant).not_to be_blank
        html_id = 'invite_members_form_' + participant.id.to_s
        find(:css, "input##{html_id}").set(true)

        click_button('not-yet-invited-submit')

        expect(current_path).to eq(invite_event_memberships_path(@event))
        updated_member = Membership.find(participant.id)
        expect(updated_member.attendance).to eq('Not Yet Invited')
        expect(page).to have_text("You may not invite more than
          #{@event.max_participants} in-person participants.".squish)
      end

      it 'invitation fails if max_virtual is exceeded by virtual
        participants'.squish do
        num_participants = @event.num_invited_virtual
        @event.max_virtual = num_participants
        @event.save!

        visit invite_event_memberships_path(@event)

        participant = @event.memberships.where(role: 'Virtual Participant')
                            .where(attendance: 'Not Yet Invited').last
        expect(participant).not_to be_blank
        html_id = 'invite_members_form_' + participant.id.to_s
        find(:css, "input##{html_id}").set(true)

        click_button('not-yet-invited-submit')

        expect(current_path).to eq(invite_event_memberships_path(@event))
        updated_member = Membership.find(participant.id)
        expect(updated_member.attendance).to eq('Not Yet Invited')
        expect(page).to have_text("You may not invite more than
          #{@event.max_virtual} virtual participants.".squish)
      end

      it 'invitation fails if max_virtual is exceeded by virtual organizers' do
        num_participants = @event.num_invited_virtual
        @event.max_virtual = num_participants
        @event.save!

        organizer = create(:membership, event: @event,
                             role: 'Virtual Organizer',
                             attendance: 'Not Yet Invited')

        visit invite_event_memberships_path(@event)
        html_id = 'invite_members_form_' + organizer.id.to_s
        find(:css, "input##{html_id}").set(true)

        click_button('not-yet-invited-submit')

        updated_member = Membership.find(organizer.id)
        expect(updated_member.attendance).to eq('Not Yet Invited')
        expect(page).to have_text("You may not invite more than
          #{@event.max_virtual} virtual participants.".squish)
        expect(current_path).to eq(invite_event_memberships_path(@event))
      end
    end

    it 'invitation fails if max_observers is exceeded' do
      @event.update_columns(event_format: 'Physical')
      num_observers = @event.num_invited_observers
      @event.max_observers = num_observers
      @event.save!

      observer = @event.memberships.where(role: 'Observer')
                                      .where(attendance: 'Not Yet Invited').last
      expect(observer).not_to be_blank
      html_id = 'invite_members_form_' + observer.id.to_s
      find(:css, "input##{html_id}").set(true)

      click_button('not-yet-invited-submit')

      expect(current_path).to eq(invite_event_memberships_path(@event))
      expect(Membership.find(observer.id).attendance).to eq('Not Yet Invited')
      expect(page).to have_text("You may not invite more than
        #{@event.max_observers} observers".squish)
    end

    it 'does not fail if max_participants is full, but observer is invited' do
      @event = Event.find(@event.id)
      @event.max_participants = @event.num_invited_participants
      @event.max_virtual = @event.num_invited_virtual
      @event.max_observers = @event.num_invited_observers + 1
      @event.save!

      observer = create(:membership, event: @event, role: 'Observer', attendance: 'Not Yet Invited')
      visit invite_event_memberships_path(@event)
      html_id = 'invite_members_form_' + observer.id.to_s
      find(:css, "input##{html_id}").set(true)
      click_button('not-yet-invited-submit')

      expect(current_path).to eq(event_memberships_path(@event))
      expect(EmailInvitationJob).to have_been_enqueued.with(observer.invitation.id, initial_email: true)
      expect(page).to have_text("Invitations were sent to 1 participants:
        #{observer.person.name}".squish)
    end
  end
end
