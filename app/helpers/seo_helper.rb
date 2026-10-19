# frozen_string_literal: true

module SeoHelper
  DEFAULT_TITLE = 'VitalHub — Arriendo de espacio flexible'
  DEFAULT_DESCRIPTION = 'Arriendo de espacio profesional para salud en Chile. Bloques flexibles o día completo con total flexibilidad.'
  SITE_NAME = 'VitalHub'

  def seo_title
    content_for?(:title) ? content_for(:title) : DEFAULT_TITLE
  end

  def seo_description
    content_for?(:meta_description) ? content_for(:meta_description) : DEFAULT_DESCRIPTION
  end

  def seo_image_url
    if content_for?(:og_image)
      absolute_url(content_for(:og_image))
    elsif site_branding.hero_image.attached?
      absolute_url(url_for(site_branding.hero_image))
    else
      site_logo_url
    end
  end

  def seo_canonical_url
    content_for?(:canonical_url) ? content_for(:canonical_url) : request.original_url
  end

  def seo_og_type
    content_for?(:og_type) ? content_for(:og_type) : 'website'
  end

  def absolute_url(path_or_url)
    return path_or_url if path_or_url.start_with?('http://', 'https://')

    host = ENV.fetch('APP_HOST', request.host_with_port)
    protocol = request.ssl? || Rails.env.production? ? 'https' : request.protocol.delete_suffix('://')
    "#{protocol}://#{host}#{path_or_url}"
  end

  def truncate_description(text, length: 155)
    return DEFAULT_DESCRIPTION if text.blank?

    truncate(text.to_s.squish, length: length, omission: '…')
  end

  def local_business_json_ld(office)
    return nil unless office

    {
      '@context' => 'https://schema.org',
      '@type' => 'ProfessionalService',
      'name' => SITE_NAME,
      'description' => DEFAULT_DESCRIPTION,
      'url' => absolute_url(root_path),
      'image' => site_logo_url,
      'address' => {
        '@type' => 'PostalAddress',
        'streetAddress' => office.address,
        'addressLocality' => office.commune,
        'addressRegion' => office.city,
        'addressCountry' => 'CL'
      }
    }.tap do |data|
      if office.latitude.present? && office.longitude.present?
        data['geo'] = {
          '@type' => 'GeoCoordinates',
          'latitude' => office.latitude,
          'longitude' => office.longitude
        }
      end
    end.to_json
  end

  def faq_page_json_ld(faqs)
    return nil if faqs.blank?

    {
      '@context' => 'https://schema.org',
      '@type' => 'FAQPage',
      'mainEntity' => faqs.map do |faq|
        {
          '@type' => 'Question',
          'name' => faq.question,
          'acceptedAnswer' => {
            '@type' => 'Answer',
            'text' => faq.answer
          }
        }
      end
    }.to_json
  end

  def space_offer_json_ld(space)
    product_image_url = if space.photos_attached?
                          absolute_url(url_for(space.cover_photo))
                        else
                          site_logo_url
                        end

    {
      '@context' => 'https://schema.org',
      '@type' => 'Product',
      'name' => space.title,
      'description' => truncate_description(space.description),
      'image' => product_image_url,
      'url' => absolute_url(space_path(space)),
      'offers' => {
        '@type' => 'Offer',
        'priceCurrency' => 'CLP',
        'price' => (space.price_per_hour_cents / 100.0).round,
        'availability' => 'https://schema.org/InStock',
        'url' => absolute_url(space_path(space))
      }
    }.to_json
  end

  def combined_json_ld(*schemas)
    parsed = schemas.compact.map { |json| JSON.parse(json) }
    return nil if parsed.empty?
    return parsed.first.to_json if parsed.one?

    parsed.to_json
  end
end
