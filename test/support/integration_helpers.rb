# frozen_string_literal: true

module IntegrationHelpers
  def sign_in_as(user)
    sign_in user
  end

  def attach_box_photo(box)
    path = Rails.root.join('test/fixtures/files/cover.jpg')
    box.photos.attach(
      io: File.open(path),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )
  end

  def with_mercadopago_stub(preference_id: 'TEST-pref-1', init_point: 'https://sandbox.mercadopago.cl/checkout', &)
    fake_pref = Object.new
    fake_pref.define_singleton_method(:create) do |_data|
      { response: { 'id' => preference_id, 'init_point' => init_point, 'sandbox_init_point' => init_point } }
    end
    fake_pref.define_singleton_method(:get) do |_id|
      { response: { 'id' => preference_id, 'init_point' => init_point, 'sandbox_init_point' => init_point } }
    end

    fake_payment = Object.new
    fake_payment.define_singleton_method(:get) do |payment_id|
      { response: { 'id' => payment_id, 'status' => 'approved', 'external_reference' => nil } }
    end

    fake_sdk = Object.new
    fake_sdk.define_singleton_method(:preference) { fake_pref }
    fake_sdk.define_singleton_method(:payment) { fake_payment }

    Mercadopago::SDK.stub(:new, ->(_token) { fake_sdk }, &)
  end

  def with_geocoder_stub(lat: -33.4264, lng: -70.6156, &)
    GeocoderService.stub(:geocode, { latitude: lat, longitude: lng }, &)
  end

  def next_monday_at(hour: 10)
    date = Date.current
    date += 1.day until date.monday?
    date += 7.days if date <= Date.current
    Time.zone.local(date.year, date.month, date.day, hour, 0)
  end

  def booking_date_param(time = next_monday_at)
    time.to_date.to_s
  end

  def booking_start_time_param(time = next_monday_at)
    time.strftime('%H:%M')
  end
end
