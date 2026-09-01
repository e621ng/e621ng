# frozen_string_literal: true

class TagCategory
  MAPPING = {
    "general" => 0,
    "gen" => 0,
    tm("{{artist}}") => 1,
    tm("{{art}}") => 1,
    "contributor" => 2,
    "contrib" => 2,
    "cont" => 2,
    tm("{{copyright}}") => 3,
    tm("{{copy}}") => 3,
    tm("{{co}}") => 3,
    "character" => 4,
    "char" => 4,
    "ch" => 4,
    "oc" => 4,
    "species" => 5,
    "spec" => 5,
    "invalid" => 6,
    "inv" => 6,
    "meta" => 7,
    "lore" => 8,
    "lor" => 8,
  }.freeze

  CANONICAL_MAPPING = {
    "General" => 0,
    tm("{{Artist}}") => 1,
    "Contributor" => 2,
    tm("{{Copyright}}") => 3,
    "Character" => 4,
    "Species" => 5,
    "Invalid" => 6,
    "Meta" => 7,
    "Lore" => 8,
  }.freeze

  MEMBER_EDITABLE_CATEGORIES = [
    "General",
    tm("{{Artist}}"),
    "Contributor",
    tm("{{Copyright}}"),
    "Character",
    "Species",
  ].freeze
  MEMBER_EDITABLE_MAPPING = CANONICAL_MAPPING.select { |k, _| MEMBER_EDITABLE_CATEGORIES.include?(k) }.freeze

  REVERSE_MAPPING = {
    0 => "general",
    1 => tm("{{artist}}"),
    2 => "contributor",
    3 => tm("{{copyright}}"),
    4 => "character",
    5 => "species",
    6 => "invalid",
    7 => "meta",
    8 => "lore",
  }.freeze

  # This mapping is used specifically for the `Tag.categories` members.
  # It defines the names of the internal symbols, not of the actual categories.
  # This allows different category names without needing to change all the symbols.
  ENUM_MAPPING = {
    0 => "general",
    1 => "artist",
    2 => "contributor",
    3 => "copyright",
    4 => "character",
    5 => "species",
    6 => "invalid",
    7 => "meta",
    8 => "lore",
  }.freeze

  SHORT_NAME_MAPPING = {
    "gen" => "general",
    tm("{{art}}") => tm("{{artist}}"),
    "cont" => "contributor",
    tm("{{copy}}") => tm("{{copyright}}"),
    "char" => "character",
    "spec" => "species",
    "inv" => "invalid",
    "meta" => "meta",
    "lor" => "lore",
  }.freeze

  HEADER_MAPPING = {
    "general" => "General",
    tm("{{artist}}") => tm("{{Artist}}"),
    "contributor" => "Contributors",
    tm("{{copyright}}") => tm("{{Copyrights}}"),
    "character" => "Characters",
    "species" => "Species",
    "invalid" => "Invalid",
    "meta" => "Meta",
    "lore" => "Lore",
  }.freeze

  ADMIN_ONLY_MAPPING = {
    "general" => false,
    tm("{{artist}}") => false,
    "contributor" => false,
    tm("{{copyright}}") => false,
    "character" => false,
    "species" => false,
    "invalid" => true,
    "meta" => true,
    "lore" => true,
  }.freeze

  HUMANIZED_MAPPING = {
    tm("{{artist}}") => {
      "slice" => 0,
      "exclusion" => %w[avoid_posting conditional_dnp epilepsy_warning sound_warning],
      "regexmap" => //,
      "formatstr" => "created by %s",
    },
    tm("{{copyright}}") => {
      "slice" => 1,
      "exclusion" => [],
      "regexmap" => //,
      "formatstr" => "(%s)",
    },
    "character" => {
      "slice" => 5,
      "exclusion" => [],
      "regexmap" => /^(.+?)(?:_\(.+\))?$/,
      "formatstr" => "%s",
    },
  }.freeze

  CATEGORIES = [
    "general",
    "species",
    "character",
    tm("{{copyright}}"),
    tm("{{artist}}"),
    "contributor",
    "invalid",
    "lore",
    "meta",
  ].freeze
  CATEGORY_IDS = CANONICAL_MAPPING.values.freeze

  SHORT_NAME_LIST = SHORT_NAME_MAPPING.keys.freeze
  HUMANIZED_LIST = [
    "character",
    tm("{{copyright}}"),
    tm("{{artist}}"),
  ].freeze
  SPLIT_HEADER_LIST = [
    "invalid",
    tm("{{artist}}"),
    "contributor",
    tm("{{copyright}}"),
    "character",
    "species",
    "general",
    "meta",
    "lore",
  ].freeze
  CATEGORIZED_LIST = [
    "invalid",
    tm("{{artist}}"),
    "contributor",
    tm("{{copyright}}"),
    "character",
    "species",
    "meta",
    "general",
    "lore",
  ].freeze

  SHORT_NAME_REGEX = SHORT_NAME_LIST.join("|").freeze
  ALL_NAMES_REGEX = MAPPING.keys.join("|").freeze
end
