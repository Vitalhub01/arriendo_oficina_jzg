# frozen_string_literal: true

module Admin
  class HomeHighlightsController < Admin::BaseController
    before_action :set_home_highlight, only: %i[edit update destroy]

    def index
      @home_highlights = HomeHighlight.ordered
    end

    def new
      @home_highlight = HomeHighlight.new
    end

    def edit; end

    def create
      @home_highlight = HomeHighlight.new(home_highlight_params)

      if @home_highlight.save
        redirect_to admin_home_highlights_path, notice: 'Destacado creado'
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @home_highlight.update(home_highlight_params)
        redirect_to admin_home_highlights_path, notice: 'Destacado actualizado'
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @home_highlight.destroy
      redirect_to admin_home_highlights_path, notice: 'Destacado eliminado'
    end

    private

    def set_home_highlight
      @home_highlight = HomeHighlight.find(params.expect(:id))
    end

    def home_highlight_params
      params.expect(home_highlight: %i[title description position visible])
    end
  end
end
