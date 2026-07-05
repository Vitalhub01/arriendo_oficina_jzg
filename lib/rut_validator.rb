# frozen_string_literal: true

module RutValidator
  module_function

  def valid?(rut)
    normalized = normalize(rut)
    return false if normalized.length < 2

    body = normalized[0..-2]
    dv = normalized[-1]
    return false unless body.match?(/\A\d+\z/)

    calculate_dv(body) == dv
  end

  def format(rut)
    normalized = normalize(rut)
    return rut if normalized.length < 2

    body = normalized[0..-2]
    dv = normalized[-1]
    formatted = body.reverse.scan(/\d{1,3}/).join('.').reverse
    "#{formatted}-#{dv}"
  end

  def normalize(rut)
    rut.to_s.delete('.').delete('-').upcase
  end

  def calculate_dv(body)
    sum = 0
    multiplier = 2
    body.reverse.each_char do |char|
      sum += char.to_i * multiplier
      multiplier = multiplier == 7 ? 2 : multiplier + 1
    end
    remainder = 11 - (sum % 11)
    case remainder
    when 11 then '0'
    when 10 then 'K'
    else remainder.to_s
    end
  end
end
