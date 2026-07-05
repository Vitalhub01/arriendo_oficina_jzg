# frozen_string_literal: true

module Owner
  class AvailabilityBlocksController < Owner::BaseController
    before_action :set_box

    def index
      @blocks = @box.availability_blocks.order(start_at: :desc)
      @block = @box.availability_blocks.build
    end

    def create
      @block = @box.availability_blocks.build(block_params)
      if @block.save
        redirect_to owner_box_availability_blocks_path(@box), notice: 'Bloqueo agregado'
      else
        @blocks = @box.availability_blocks.order(start_at: :desc)
        render :index, status: :unprocessable_content
      end
    end

    def destroy
      @box.availability_blocks.find(params.expect(:id)).destroy
      redirect_to owner_box_availability_blocks_path(@box), notice: 'Bloqueo eliminado'
    end

    private

    def set_box
      @box = current_user.boxes.find(params.expect(:box_id))
    end

    def block_params
      params.expect(availability_block: %i[start_at end_at reason])
    end
  end
end
