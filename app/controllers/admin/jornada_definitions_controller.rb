# frozen_string_literal: true

module Admin
  class JornadaDefinitionsController < Admin::BaseController
    before_action :set_jornada_definition, only: %i[show edit update destroy]

    def index
      @jornada_definitions = JornadaDefinition.includes(:space, :office).order(:position, :name)
    end

    def show; end

    def new
      @jornada_definition = JornadaDefinition.new
    end

    def edit; end

    def create
      @jornada_definition = JornadaDefinition.new(jornada_definition_params)

      if @jornada_definition.save
        redirect_to admin_jornada_definitions_path, notice: 'Jornada creada'
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @jornada_definition.update(jornada_definition_params)
        redirect_to admin_jornada_definition_path(@jornada_definition), notice: 'Jornada actualizada'
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @jornada_definition.destroy
      redirect_to admin_jornada_definitions_path, notice: 'Jornada eliminada'
    end

    private

    def set_jornada_definition
      @jornada_definition = JornadaDefinition.find(params.expect(:id))
    end

    def jornada_definition_params
      params.expect(
        jornada_definition: [:name, :space_id, :office_id, :start_time, :end_time,
                             :price_cents, :active, :position]
      )
    end
  end
end
