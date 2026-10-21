# frozen_string_literal: true

namespace :active_storage do
  desc 'Enqueue Sidekiq jobs to preprocess variants for all uploaded space photos and gallery items'
  task preprocess_variants: :environment do
    counts = ActiveStorageVariantsTasks.enqueue_all
    puts "Enqueued #{counts[:space_photos]} space photo job(s) and #{counts[:gallery_items]} gallery item job(s)."
  end

  desc 'Preprocess variants synchronously (run on worker container; one image at a time)'
  task preprocess_variants_now: :environment do
    counts = ActiveStorageVariantsTasks.process_all_sync
    puts "Preprocessed variants for #{counts[:space_photos]} space photo(s) and #{counts[:gallery_items]} gallery item(s)."
  end
end

module ActiveStorageVariantsTasks
  module_function

  def enqueue_all
    space_photos = 0
    gallery_items = 0

    SpacePhoto.find_each do |photo|
      next unless photo.image.attached?

      PreprocessSpacePhotoVariantsJob.perform_later(photo.id)
      space_photos += 1
    end

    GalleryItem.find_each do |item|
      next unless item.image.attached?

      PreprocessGalleryItemVariantsJob.perform_later(item.id)
      gallery_items += 1
    end

    { space_photos: space_photos, gallery_items: gallery_items }
  end

  def process_all_sync
    space_photos = 0
    gallery_items = 0

    SpacePhoto.find_each do |photo|
      next unless photo.image.attached?

      PreprocessSpacePhotoVariantsJob.perform_now(photo.id)
      space_photos += 1
    end

    GalleryItem.find_each do |item|
      next unless item.image.attached?

      PreprocessGalleryItemVariantsJob.perform_now(item.id)
      gallery_items += 1
    end

    { space_photos: space_photos, gallery_items: gallery_items }
  end
end
