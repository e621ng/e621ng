class PostImageHash < ApplicationRecord
  class UnhashableImage < Exception; end
  self.primary_key = :post_id

  belongs_to :post

  validates :post, uniqueness: true

  def self.for_post(post)

    stdout, stderr, status = Open3.capture3(Danbooru.config.intensities_path, path)

    unless status == 0
      raise UnhashableImage.new(stdout + stderr)
    end
    self.post_id = post.id

  end
end
