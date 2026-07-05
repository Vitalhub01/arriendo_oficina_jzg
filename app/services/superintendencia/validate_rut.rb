# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Superintendencia
  class ValidateRut
    BASE_URL = 'https://apis.superdesalud.gob.cl/api/prestadores/rut'

    def initialize(professional_profile)
      @profile = professional_profile
    end

    def call
      if stub_mode?
        stub_response
      else
        api_response
      end
    end

    private

    attr_reader :profile

    def stub_mode?
      ENV['SUPERSALUD_API_KEY'].blank? || ENV['SUPERSALUD_STUB'] == 'true'
    end

    def stub_response
      {
        valid: true,
        data: {
          rut: profile.full_rut,
          verified_at: Time.current.iso8601,
          source: 'stub'
        }
      }
    end

    def api_response
      rut_number = profile.rut.to_s.delete('.').delete('-')[0..-2]
      uri = URI("#{BASE_URL}/#{rut_number}.json/")
      uri.query = URI.encode_www_form(apikey: ENV.fetch('SUPERSALUD_API_KEY'))

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 15) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end

      if response.is_a?(Net::HTTPSuccess)
        body = JSON.parse(response.body)
        {
          valid: body['nro_registro'].present? || body['nombres'].present?,
          data: body
        }
      else
        { valid: false, data: { status: response.code, body: response.body } }
      end
    rescue StandardError => e
      Rails.logger.error("[Superintendencia::ValidateRut] #{e.class}: #{e.message}")
      { valid: false, data: { error: e.message } }
    end
  end
end
