# Copyright (c) 2018 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'rails_helper'

# EmailTemplateSelector should return the correct email template name
# for each workshop type, membership attendance status, and membership role
describe 'InvitationTemplateSelector' do
  GetSetting.site_setting('event_formats').each do |event_format|
    context "For #{event_format} events" do
      GetSetting.site_setting('event_types').sample(2).each do |event_type|
        context "Of type #{event_type}" do
          let(:event) { build(:event, event_type:   event_type,
                                      event_format: event_format) }

          attendances = Membership::ATTENDANCE.dup - ['Confirmed']
          attendances.sample(2).each do |attendance|
            context "For membership attendance '#{attendance}'" do
              let(:membership) { build(:membership, event: event,
                                               attendance: attendance) }

              it "template: #{event_format}-#{event_type}-#{attendance}" do

                template_name = "#{event_format}-#{event_type}-#{attendance}"

                templates = InvitationTemplateSelector.new(membership)
                                                      .set_templates

                expect(templates[:template_name]).to eq(template_name)
              end

              if event_format == 'Hybrid'
                it 'appends -Virtual for if member role includes Virtual' do
                  membership.role = 'Virtual Particiant'
                  template_name = "Hybrid-#{event_type}-#{attendance}-Virtual"

                  templates = InvitationTemplateSelector.new(membership)
                                                        .set_templates

                  expect(templates[:template_name]).to eq(template_name)
                end
              end

              if event_format == 'Online'
                it 'does not append -Virtual for Virtual Participants of Online
                    events'.squish do
                  membership.role = 'Virtual Particiant'
                  template_name = "Online-#{event_type}-#{attendance}"

                  templates = InvitationTemplateSelector.new(membership)
                                                        .set_templates

                  expect(templates[:template_name]).to eq(template_name)
                end
              end
            end # context ... attendance
          end # attendances.each
        end # context ... event_type
      end # event_types.each
    end # context ... event_format
  end # event_formats.each
end
