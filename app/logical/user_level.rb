# frozen_string_literal: true

module UserLevel
  MAPPING = {
    "Anonymous" => 0,
    "Blocked" => 10,
    "Member" => 20,
    "Privileged" => 30,
    "Former Staff" => 40,
    "Staff" => 50,
    "Janitor" => 60,
    "Moderator" => 70,
    "Admin" => 80,
  }.freeze
  REVERSE_MAPPING = MAPPING.invert.freeze

  def self.normalize(name)
    name.downcase.tr(" ", "_")
  end

  MAPPING.each do |name, level|
    const_set(name.upcase.tr(" ", "_"), level)
  end

  # Normalized role names.
  # Used primarily to create helper methods (`#is_admin?`) and access gates (`#admin_only`).
  ROLES = MAPPING.keys.map { |n| normalize(n) }.freeze

  # Levels that can be manually assigned to users.
  # Existing user account cannot be made Anonymous - things will break in unexpected ways.
  # Users should not be manually blocked - a permanent ban should be created instead.
  ASSIGNABLE_LEVELS = MAPPING.except("Anonymous", "Blocked").freeze

  # Normalized roles that are exported as data attributes in the body tag.
  BODY_ATTRIBUTE_ROLES = ASSIGNABLE_LEVELS.keys.map { |n| normalize(n) }.freeze
end
