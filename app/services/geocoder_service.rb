# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

class GeocoderService
  NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search'

  def self.geocode(address, city: 'Santiago', commune: nil)
    query = [address, commune, city, 'Chile'].compact.join(', ')
    uri = URI(NOMINATIM_URL)
    uri.query = URI.encode_www_form(q: query, format: 'json', limit: 1)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 10) do |http|
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'ArriendoDeBox/1.0'
      http.request(request)
    end

    results = JSON.parse(response.body)
    return nil if results.empty?

    { latitude: results.first['lat'].to_f, longitude: results.first['lon'].to_f }
  rescue StandardError
    nil
  end
end
