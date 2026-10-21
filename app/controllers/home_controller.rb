# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    HomeIndexQuery.call.each { |key, value| instance_variable_set(:"@#{key}", value) }
  end
end
