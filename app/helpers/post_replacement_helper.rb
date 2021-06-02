module PostReplacementHelper
  def replacement_thumbnail(replacement)
    return tag.a(image_tag(replacement.replacement_thumb_url), href: replacement.replacement_file_url) if replacement.file_visible_to?(CurrentUser.user)
    image_tag(replacement.replacement_thumb_url)
  end
end
