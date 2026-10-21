# frozen_string_literal: true

Rails.application.config.to_prepare do
  extension = ActiveStorageVariantLimiter::VariantWithRecordExtension
  variant_extension = ActiveStorageVariantLimiter::VariantExtension

  unless ActiveStorage::VariantWithRecord.included_modules.include?(extension)
    ActiveStorage::VariantWithRecord.prepend(extension)
  end

  unless ActiveStorage::Variant.included_modules.include?(variant_extension)
    ActiveStorage::Variant.prepend(variant_extension)
  end
end
