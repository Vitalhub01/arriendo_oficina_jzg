# frozen_string_literal: true

module Owner
  class BoxesController < Owner::BaseController
    require 'csv'

    before_action :set_box, only: %i[show edit update destroy publish calendar export_bookings]

    def index
      @boxes = current_user.boxes.order(created_at: :desc)
    end

    def show
      @bookings = @box.bookings.order(start_at: :desc).limit(20)
      @booking_series = @box.booking_series.active.order(:starts_on)
      @month_revenue = @box.bookings.confirmed
                           .where(start_at: Time.current.all_month)
                           .sum(:total_amount_cents)
      @pending_count = @box.bookings.pending_payment.count
    end

    def calendar
      @week_start = parse_week_start
      @schedule = AvailabilityScheduleBuilder.new(@box, week_start: @week_start).build
      @week_bookings = @box.bookings.where(start_at: @week_start.beginning_of_day..(@week_start + 6.days).end_of_day)
    end

    def export_bookings
      bookings = @box.bookings.order(:start_at)
      csv = CSV.generate(headers: true) do |row|
        row << %w[id fecha inicio fin horas estado total arrendatario]
        bookings.each do |b|
          row << [b.id, b.start_at.to_date, b.start_at, b.end_at, b.hours, b.status, b.total_amount_cents,
                  b.renter.name]
        end
      end
      send_data csv, filename: "reservas-#{@box.id}.csv", type: 'text/csv'
    end

    def new
      @box = current_user.boxes.build
    end

    def edit; end

    def create
      @box = current_user.boxes.build(box_params)
      geocode_if_needed(@box)

      if @box.save
        redirect_to owner_box_availability_rules_path(@box), notice: 'Box creado. Configura los horarios.'
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      @box.assign_attributes(box_params)
      geocode_if_needed(@box)

      if @box.save
        redirect_to owner_box_path(@box), notice: 'Box actualizado'
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @box.destroy
      redirect_to owner_boxes_path, notice: 'Box eliminado'
    end

    def publish
      @box.status = :published
      if @box.save
        redirect_to owner_box_path(@box), notice: 'Box publicado'
      else
        redirect_to owner_box_path(@box), alert: @box.errors.full_messages.join(', ')
      end
    end

    private

    def set_box
      @box = current_user.boxes.find(params.expect(:id))
    end

    def box_params
      params.expect(
        box: [:title, :description, :address, :commune, :city,
              :latitude, :longitude, :box_type, :price_per_hour_cents,
              :minimum_hours, :status, { amenities: {}, photos: [] }]
      )
    end

    def geocode_if_needed(box)
      return if box.latitude.present? && box.longitude.present?

      coords = GeocoderService.geocode(box.address, city: box.city, commune: box.commune)
      return unless coords

      box.latitude = coords[:latitude]
      box.longitude = coords[:longitude]
    end

    def parse_week_start
      if params[:week_start].present?
        Date.parse(params[:week_start]).beginning_of_week(:monday)
      else
        Date.current.beginning_of_week(:monday)
      end
    rescue ArgumentError
      Date.current.beginning_of_week(:monday)
    end
  end
end
