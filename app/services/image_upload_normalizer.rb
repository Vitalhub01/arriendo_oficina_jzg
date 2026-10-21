# frozen_string_literal: true

class ImageUploadNormalizer
  MAX_EDGE = 2400
  JPEG_QUALITY = 85
  ALLOWED_TYPES = %w[image/jpeg image/png image/webp].freeze
  METADATA_KEY = 'upload_normalized'

  def self.normalize!(attachment)
    return unless attachment.attached?

    blob = attachment.blob
    return unless ALLOWED_TYPES.include?(blob.content_type)
    return if blob.metadata[METADATA_KEY]

    attachment.blob.open do |input|
      output = process(input.path, blob.content_type)
      next unless output

      attachment.attach(
        io: output,
        filename: jpeg_filename(blob.filename),
        content_type: 'image/jpeg',
        metadata: blob.metadata.merge(METADATA_KEY => true)
      )
      output.close
    end
  end

  def self.process(path, content_type)
    require 'image_processing/vips'

    image = Vips::Image.new_from_file(path, access: :sequential)
    needs_resize = image.width > MAX_EDGE || image.height > MAX_EDGE

    return nil unless needs_resize

    tempfile = Tempfile.new(['upload', '.jpg'])
    ImageProcessing::Vips
      .source(path)
      .resize_to_limit(MAX_EDGE, MAX_EDGE)
      .convert('jpg')
      .saver(quality: JPEG_QUALITY, strip: true)
      .call(destination: tempfile.path)

    File.open(tempfile.path, 'rb')
  end

  def self.jpeg_filename(filename)
    base = filename.to_s.sub(/\.[^.]+\z/i, '')
    ActiveStorage::Filename.new("#{base}.jpg")
  end
end
