# frozen_string_literal: true

class PagesController < ApplicationController
  TERMS_PDF = Rails.public_path.join('documents/terminos-y-condiciones-generales-v1.pdf').freeze

  def terms
    send_file TERMS_PDF,
              filename: 'terminos-y-condiciones-generales-v1.pdf',
              type: 'application/pdf',
              disposition: 'inline'
  end

  def privacy; end
  def cancellation; end
end
