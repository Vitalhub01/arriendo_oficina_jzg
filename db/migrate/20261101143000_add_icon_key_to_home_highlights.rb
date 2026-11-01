# frozen_string_literal: true

class AddIconKeyToHomeHighlights < ActiveRecord::Migration[8.0]
  TITLE_ICON_PATTERNS = [
    [/flexibilidad/i, 'clock'],
    [/est[aá]ndar|equipado/i, 'sparkles'],
    [/luminosidad|luminoso/i, 'sun'],
    [/climat/i, 'cloud'],
    [/ubicaci/i, 'map_pin'],
    [/acogedor|tranquilidad|experiencia/i, 'heart'],
    [/conectividad|tecnolog/i, 'wifi'],
    [/comodidad/i, 'squares_plus'],
    [/reserva.*online|online/i, 'rocket_launch'],
    [/reserva/i, 'ticket']
  ].freeze

  SEED_ICONS = {
    'Flexibilidad' => 'clock',
    'Equipado' => 'clipboard_document_check',
    'Ubicación' => 'map_pin',
    'Reserva online' => 'rocket_launch'
  }.freeze

  def up
    add_column :home_highlights, :icon_key, :string, null: false, default: HomeHighlightIcons::DEFAULT_KEY

    HomeHighlight.reset_column_information
    HomeHighlight.find_each do |highlight|
      icon_key = SEED_ICONS[highlight.title] || icon_for_title(highlight.title)
      highlight.update_column(:icon_key, icon_key)
    end
  end

  def down
    remove_column :home_highlights, :icon_key
  end

  private

  def icon_for_title(title)
    TITLE_ICON_PATTERNS.each do |pattern, icon_key|
      return icon_key if title.match?(pattern)
    end

    HomeHighlightIcons::DEFAULT_KEY
  end
end
