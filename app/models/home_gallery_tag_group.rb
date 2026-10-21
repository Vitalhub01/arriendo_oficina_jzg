# frozen_string_literal: true

# Stand-in for an array of gallery items on the home page (cover + total count).
class HomeGalleryTagGroup
  attr_reader :cover

  def initialize(cover, total_count)
    @cover = cover
    @total_count = total_count
  end

  def first
    cover
  end

  def size
    @total_count
  end
end
