# frozen_string_literal: true

require 'test_helper'

class IosUiZoomTest < ActionDispatch::IntegrationTest
  IPHONE_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
  ANDROID_UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36'

  test 'ios user agent adds zoom class on public layout html' do
    get root_path, headers: { 'HTTP_USER_AGENT' => IPHONE_UA }
    assert_response :success
    assert_select 'html.ios-ui-zoom-out', 1
  end

  test 'android user agent leaves public layout html without zoom class' do
    get root_path, headers: { 'HTTP_USER_AGENT' => ANDROID_UA }
    assert_response :success
    assert_select 'html.ios-ui-zoom-out', count: 0
    assert_select 'html[lang=?]', 'es'
  end
end
