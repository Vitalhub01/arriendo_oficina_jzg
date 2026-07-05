# frozen_string_literal: true

module Admin
  class FaqsController < Admin::BaseController
    before_action :set_faq, only: %i[show edit update destroy]

    def index
      @faqs = Faq.ordered
    end

    def show; end

    def new
      @faq = Faq.new
    end

    def edit; end

    def create
      @faq = Faq.new(faq_params)

      if @faq.save
        redirect_to admin_faqs_path, notice: 'Pregunta creada'
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @faq.update(faq_params)
        redirect_to admin_faqs_path, notice: 'Pregunta actualizada'
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @faq.destroy
      redirect_to admin_faqs_path, notice: 'Pregunta eliminada'
    end

    private

    def set_faq
      @faq = Faq.find(params.expect(:id))
    end

    def faq_params
      params.expect(faq: %i[question answer position visible])
    end
  end
end
