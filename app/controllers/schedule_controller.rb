# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

class ScheduleController < ApplicationController
  before_action :set_event, :set_attendance, :set_time_zone
  before_action :set_schedule, only: [:show, :update, :destroy]
  before_action :set_lock_time, only: [:new, :edit, :update, :create]

  before_action :authenticate_user!, except: [:index]
  after_action :flash_notice, only: [:create, :update, :edit]

  # GET /events/:event_id/schedule
  # GET /events/:event_id/schedule.json
  def index
    @schedules = DefaultSchedule.new(@event, current_user).schedules
    @schedule_policy = Schedule.new(event: @event)

    redirect_to sign_in_path if nothing_to_see_here(@schedules)
  end

  def nothing_to_see_here(schedules)
    request.format.html? && schedules.empty? && !current_user
  end

  # POST /events/:event_id/schedule/schedule_publish
  def publish_schedule
    if @event.update(publish_schedule: params[:publish_schedule])
      respond_to do |format|
        format.js
      end
    end
  end

  # GET /schedule/1
  # GET /schedule/1.json
  def show; end

  # GET /schedule/new
  def new
    authorize Schedule.new(event: @event)
    @day = params[:day].to_date
    new_params = { new_item: true, event_id: @event.id,
                   start_time: @day.in_time_zone, updated_by: current_user.name }
    @schedule = ScheduleItem.new(new_params).schedule
    @members = @event.members

    @form_action = 'create'
  end

  # GET /schedule/1/edit
  def edit
    @schedule = ScheduleItem.get(params[:id])
    authorize @schedule
    @day = @schedule.day
    @form_action = 'update'
    session[:return_to] = request.referer
  end

  # POST /events/:event_id/schedule
  # POST /events/:event_id/schedule.json
  def create
    @schedule = ScheduleItem.new(schedule_params
      .merge(updated_by: current_user.name)).schedule
    authorize @schedule

    respond_to do |format|
      if @schedule.valid? && @schedule.save
        if @schedule.notify_staff?
          ScheduleNotice.new(schedule: @schedule).create
        end
        day = @schedule.start_time.to_date
        name = @schedule.name
        format.html do
          redirect_to event_schedule_day_path(@event, day),
                      notice: "\"#{name}\" was successfully scheduled."
        end
        format.json { render :show, status: :created, location: @schedule }
      else
        @day = Date.parse(params[:day])
        @form_action = 'create'
        prefill_lecture_fields if @schedule.lecture
        format.html { render :new }
        format.json do
          render json: @schedule.errors, status: :unprocessable_entity
        end
      end
    end
  end

  # PATCH/PUT /event/:event_id/schedule/1
  # PATCH/PUT /event/:event_id/schedule/1.json
  def update
    authorize @schedule
    original_item = @schedule.dup
    original_lecture = @schedule.lecture.dup

    merged_params = ScheduleItem.update(@schedule, schedule_params
                                .merge(updated_by: current_user.name))

    if policy(@schedule).update_staff_item?
      staff_item = schedule_params[:staff_item] || false
      merged_params['staff_item'] = staff_item
    end
    @day = @schedule.start_time.to_date

    if session[:return_to]
      from_where_we_came = session[:return_to]
    else
      from_where_we_came = event_schedule_index_path(@event)
    end

    respond_to do |format|
      if @schedule.update(merged_params)
        if params[:change_similar]
          ScheduleItem.update_others(original_item, merged_params)
        end
        if @schedule.notify_staff?
          ScheduleNotice.new(original_schedule: original_item,
                             original_lecture: original_lecture,
                             updated_schedule: @schedule,
                             changed_similar: params[:change_similar]).update
        end

        format.html do
          redirect_to from_where_we_came,
                      notice: "\"#{@schedule.name}\" was successfully updated."
        end
        format.json { render :show, status: :ok, location: @schedule }
      else
        unless @schedule.lecture_id.nil?
          @schedule.name = @schedule.lecture.title
          @schedule.description = @schedule.lecture.abstract
        end
        @form_action = 'update'
        format.html { render :edit }
        format.json do
          render json: @schedule.errors, status: :unprocessable_entity
        end
      end
    end
  end

  # DELETE /schedule/1
  # DELETE /schedule/1.json
  def destroy
    authorize @schedule
    if @schedule.notify_staff?
      ScheduleNotice.new(schedule: @schedule,
                         changed_similar: params[:change_similar]).destroy
    end
    if @schedule.lecture.blank?
      @schedule.destroy
    else
      @schedule.lecture.destroy # dependent: :destroy
    end

    respond_to do |format|
      format.html do
        redirect_to event_schedule_index_path(@event),
                    notice: 'Schedule item was successfully removed.'
      end
      format.json { head :no_content }
    end
  end

  private

  def set_lock_time
    @lock_time = GetSetting.schedule_lock_time(@event.location)
  end

  def prefill_lecture_fields
    @schedule.name = @schedule.lecture.title
    @schedule.description = @schedule.lecture.abstract
  end

  def set_schedule
    @schedule = Schedule.find(params[:id])
  end

  def schedule_params
    params.require(:schedule)
          .permit(:id, :event_id, :start_time, :end_time, :earliest, :latest,
                  :name, :description, :location, :day, :staff_item,
                  lecture_attributes: [:person_id, :id, :keywords,
                                       :do_not_publish])
  end

  def flash_notice
    return if @schedule.flash_notice.blank?
    @schedule.flash_notice.each do |k, v|
      flash[k] = "<strong>#{k.capitalize}:</strong> #{v}"
    end
  end
end
