# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

class LecturesController < ApplicationController
  before_action :set_event, :set_time_zone, except: [:today, :current, :next]
  before_action :set_lecture, only: [:update, :destroy]
  before_action :authenticate_user!, except: [:index, :today, :current, :next]

  # GET /events/:event_id/lectures
  # GET /events/:event_id/lectures.json
  def index
    redirect_to event_schedule_index_path(@event) if request.format.html?
    @lectures = @event.lectures.includes(:person).order(:start_time)
  end

  # GET /lectures/today/room.rss
  def today
    @lectures = GetLectures.new(room_param).todays_lectures
    @schedule_url, @room = schedule_url_and_room(@lectures)
    redirect_to @schedule_url if request.format.html?
  end

  # GET /lectures/current/room.rss
  def current
    @lecture = GetLectures.new(room_param).current
    @schedule_url, @room = schedule_url_and_room(@lecture)
    redirect_to @schedule_url if request.format.html?
  end

  # GET /lectures/next/room.rss
  def next
    @lecture = GetLectures.new(room_param).next
    @schedule_url, @room = schedule_url_and_room(@lecture)
    redirect_to @schedule_url if request.format.html?
  end


  # POST /lectures
  # POST /lectures.json
  def create
    @lecture = Lecture.new(lecture_params)
    authorize @lecture

    respond_to do |format|
      if @lecture.save
        format.html { redirect_to @lecture, notice: 'Lecture was successfully created.' }
        format.json { render :show, status: :created, location: @lecture }
      else
        format.html { render :new }
        format.json { render json: @lecture.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /lectures/1
  # PATCH/PUT /lectures/1.json
  def update
    authorize @lecture
    respond_to do |format|
      if @lecture.update(lecture_params)
        format.html { redirect_to @lecture, notice: 'Lecture was successfully updated.' }
        format.json { render :show, status: :ok, location: @lecture }
      else
        format.html { render :edit }
        format.json { render json: @lecture.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /lectures/1
  # DELETE /lectures/1.json
  def destroy
    authorize @lecture
    @lecture.destroy
    respond_to do |format|
      format.html { redirect_to lectures_url, notice: 'Lecture was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

    def schedule_url_and_room(lecture)
      schedule_url = events_future_url
      room = room_param
      unless lecture.blank?
        lecture = lecture.first unless lecture.is_a?(Lecture)
        schedule_url = event_schedule_index_url(lecture.event)
        room = lecture.room
      end
      [schedule_url, room]
    end

    def set_lecture
      @lecture = Lecture.find_by_id(params[:id])
    end

  def lecture_params
    params.require(:lecture).permit(:event_id, :person_id, :title, :start_time, :end_time, :abstract, :notes, :filename, :room, :publish, :tweeted, :hosting_license, :archiving_license, :hosting_release, :archiving_release, :authors, :copyright_owners, :publication_details, :keywords, :updated_by)
  end

  def room_param
    params.require(:room)
  end
end
