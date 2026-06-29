# frozen_string_literal: true

class UserIncludeBlueprint < Blueprinter::Base
  identifier :id

  field :name
  field :level
  field :level_string

  field :is do |user|
    output = {}

    # Convenience methods generated in the User model.
    UserLevel::MAPPING.each_key do |name|
      normalized_name = UserLevel.normalize(name)
      output[normalized_name] = user.try(:"is_#{normalized_name}?")
    end

    output
  end

  field :can do |user|
    {
      approve_posts: user.can_approve_posts?,
      upload_free: user.can_upload_free?,
    }
  end

  field :settings do |user|
    {
      hotkeys: user.enable_keyboard_navigation?,
      per_page: user.per_page,
      default_image_size: user.default_image_size,
      comment_threshold: user.comment_threshold,
      blacklist_users: user.blacklist_users?,
      autocomplete: user.enable_auto_complete?,
    }
  end

  field :blacklist do |user|
    user.blacklisted_tags.to_s.split("\n")
  end
end
