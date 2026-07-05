# frozen_string_literal: true

module Owner
  class AvailabilityRulesController < Owner::BaseController
    before_action :set_box

    def index
      @rules = @box.availability_rules.order(:day_of_week, :start_time)
      @rule = @box.availability_rules.build
    end

    def create
      @rule = @box.availability_rules.build(rule_params)
      if @rule.save
        redirect_to owner_box_availability_rules_path(@box), notice: 'Horario agregado'
      else
        @rules = @box.availability_rules.order(:day_of_week, :start_time)
        render :index, status: :unprocessable_content
      end
    end

    def destroy
      @box.availability_rules.find(params.expect(:id)).destroy
      redirect_to owner_box_availability_rules_path(@box), notice: 'Horario eliminado'
    end

    private

    def set_box
      @box = current_user.boxes.find(params.expect(:box_id))
    end

    def rule_params
      params.expect(availability_rule: %i[day_of_week start_time end_time valid_from valid_until])
    end
  end
end
