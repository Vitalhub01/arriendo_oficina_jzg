# frozen_string_literal: true

class SitemapsController < ApplicationController
  def show
    @spaces = Space.published_spaces.order(updated_at: :desc)
    @host = ENV.fetch('APP_HOST', request.host_with_port)
    @protocol = request.ssl? || Rails.env.production? ? 'https' : request.protocol.delete_suffix('://')
  end
end
