# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'base64'

module Invoicing
  class LibredteClient
    BOLETA_TIPO_DTE = 39
    API_BASE_URL = ENV.fetch('LIBREDTE_API_URL', 'https://libredte.cl/api')

    def emit_boleta(payment)
      if stub_mode?
        stub_emit(payment)
      else
        api_emit(payment)
      end
    end

    private

    def stub_mode?
      Rails.env.development? || Rails.env.test? || ENV['LIBREDTE_STUB'] == 'true'
    end

    def stub_emit(payment)
      {
        success: true,
        folio: "DEV-#{payment.id}",
        provider_id: "stub-#{SecureRandom.hex(4)}",
        pdf_binary: stub_pdf_binary(payment),
        raw_response: {
          stub: true,
          payment_id: payment.id,
          amount_cents: payment.amount_cents
        }
      }
    end

    def api_emit(payment)
      temporary = emit_temporary_dte(payment)
      return failure('emitir', temporary) unless temporary[:success]

      generated = generate_real_dte(temporary[:body])
      return failure('generar', generated) unless generated[:success]

      folio = generated[:folio]
      emisor_rut = emisor_rut_normalized
      pdf_binary = fetch_pdf(folio, emisor_rut)
      return failure('pdf', { raw_response: { error: 'PDF vacío o no disponible' } }) if pdf_binary.blank?

      {
        success: true,
        folio: folio.to_s,
        provider_id: generated[:track_id]&.to_s,
        pdf_binary: pdf_binary,
        raw_response: {
          emitir: temporary[:raw_response],
          generar: generated[:raw_response]
        }
      }
    rescue StandardError => e
      Rails.logger.error("[Invoicing::LibredteClient] #{e.class}: #{e.message}")
      failure('exception', { raw_response: { error: e.message } })
    end

    def emit_temporary_dte(payment)
      response = post_json(
        '/dte/documentos/emitir',
        dte_payload(payment),
        normalizar: 1,
        formato: 'json',
        email: 0
      )
      parse_json_response(response)
    end

    def generate_real_dte(temporary_body)
      response = post_json('/dte/documentos/generar', temporary_body, email: 0)
      parsed = parse_json_response(response)
      return parsed unless parsed[:success]

      body = parsed[:body] || parsed[:raw_response]
      {
        success: true,
        folio: extract_folio(body),
        track_id: extract_track_id(body),
        raw_response: parsed[:raw_response],
        body: body
      }
    end

    def fetch_pdf(folio, emisor_rut)
      path = "/dte/dte_emitidos/pdf/#{BOLETA_TIPO_DTE}/#{folio}/#{emisor_rut}"
      response = get_binary("#{path}?formato=general&papelContinuo=0")
      return nil unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    def dte_payload(payment)
      booking = payment.booking
      space = booking.space
      receptor_rut = payment.payer.professional_profile&.full_rut || payment.payer.email

      {
        Encabezado: {
          IdDoc: {
            TipoDTE: BOLETA_TIPO_DTE
          },
          Emisor: {
            RUTEmisor: emisor_rut_normalized
          },
          Receptor: {
            RUTRecep: receptor_rut,
            RznSocRecep: payment.payer.name
          }
        },
        Detalle: [
          {
            NmbItem: "Arriendo #{space.title} — Reserva ##{booking.id}",
            QtyItem: 1,
            PrcItem: payment.amount_cents
          }
        ]
      }
    end

    def post_json(path, body, query_params = {})
      uri = build_uri(path, query_params)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', read_timeout: 30) do |http|
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['Authorization'] = auth_header
        request.body = body.to_json
        http.request(request)
      end
      response
    end

    def get_binary(path)
      uri = build_uri(path)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', read_timeout: 30) do |http|
        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = auth_header
        http.request(request)
      end
    end

    def build_uri(path, query_params = {})
      base = API_BASE_URL.chomp('/')
      full_path = path.start_with?('/') ? path : "/#{path}"
      uri = URI("#{base}#{full_path}")
      uri.query = URI.encode_www_form(query_params) if query_params.present?
      uri
    end

    def auth_header
      token = ENV.fetch('LIBREDTE_API_TOKEN', '')
      "Basic #{Base64.strict_encode64("#{token}:")}"
    end

    def emisor_rut_normalized
      RutValidator.format(ENV.fetch('LIBREDTE_EMISOR_RUT', ''))
    end

    def parse_json_response(response)
      body = JSON.parse(response.body)
      success = response.is_a?(Net::HTTPSuccess)

      {
        success: success,
        body: body,
        raw_response: body
      }
    rescue JSON::ParserError => e
      {
        success: false,
        body: nil,
        raw_response: { error: e.message, status: response.code, body: response.body }
      }
    end

    def extract_folio(body)
      return unless body

      body['folio'] || body.dig('dte', 'folio') || body.dig('Encabezado', 'IdDoc', 'Folio')
    end

    def extract_track_id(body)
      return unless body

      body['track_id'] || body['trackid'] || body['TrackID'] || body['dte']
    end

    def failure(step, context)
      {
        success: false,
        folio: nil,
        provider_id: nil,
        pdf_binary: nil,
        raw_response: { step: step, **(context[:raw_response] || context) }
      }
    end

    def stub_pdf_binary(payment)
      <<~PDF
        %PDF-1.4
        1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
        2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
        3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R/Contents 4 0 R>>endobj
        4 0 obj<</Length 44>>stream
        BT /F1 12 Tf 100 700 Td (Boleta DEV-#{payment.id}) Tj ET
        endstream
        endobj
        xref
        0 5
        0000000000 65535 f
        0000000009 00000 n
        0000000058 00000 n
        0000000115 00000 n
        0000000206 00000 n
        trailer<</Size 5/Root 1 0 R>>
        startxref
        300
        %%EOF
      PDF
    end
  end
end
