# frozen_string_literal: true

Rails.application.config.to_prepare do
  ActiveStorage::VariantWithRecord.prepend(ActiveStorageVariantLimiter::VariantWithRecordExtension)
  ActiveStorage::Variant.prepend(ActiveStorageVariantLimiter::VariantExtension)
end
