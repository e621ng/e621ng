class TagNameValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    normalized = Tag.normalize_name(value)
    case normalized
    when /\A_*\z/
      record.errors.add(attribute,  "'#{value}' cannot be blank")
    when /\*/
      record.errors.add(attribute,  "'#{value}' cannot contain asterisks ('*')")
    when /,/
      record.errors.add(attribute,  "'#{value}' cannot contain commas (',')")
    when /#/
      record.errors.add(attribute,  "'#{value}' cannot contain octothorpes ('#')")
    when /\$/
      record.errors.add(attribute,  "'#{value}' cannot contain peso signs ('$')")
    when /%/
      record.errors.add(attribute,  "'#{value}' cannot contain percent signs ('%')")
    when /\\/
      record.errors.add(attribute,  "'#{value}' cannot contain back slashes ('\\')")
    when /\A~/
      record.errors.add(attribute,  "'#{value}' cannot begin with a tilde ('~')")
    when /\A-/
      record.errors.add(attribute,  "'#{value}' cannot begin with a dash ('-')")
    when /\A:/
      record.errors.add(attribute,  "'#{value}' cannot begin with a colon (':')")
    when /\A_/
      record.errors.add(attribute, "'#{value}' cannot begin with an underscore ('_')")
    when /_\z/
      record.errors.add(attribute, "'#{value}' cannot end with an underscore ('_')")
    when /[_\-~]{2}/
      record.errors.add(attribute, "'#{value}' cannot contain consecutive underscores, hyphens or tildes")
    when /[^[:graph:]]/
      record.errors.add(attribute, "'#{value}' cannot contain non-printable characters")
    when /\A[-~+_`(){}\[\]\/]/
      record.errors.add(attribute, "'#{value}' cannot begin with a '#{value[0]}'")
    when /\A(#{Tag::METATAGS.join("|")}):(.+)\z/i
      record.errors.add(attribute, "'#{value}' cannot begin with '#{$1}:'")
    when /\A(#{Tag.categories.regexp}):(.+)\z/i
      record.errors.add(attribute, "'#{value}' cannot begin with '#{$1}:'")
    end

    if normalized =~ /[^[:ascii:]]/ && !options[:disable_ascii_check] == true
      record.errors.add(attribute,  "'#{value}' must consist of only ASCII characters")
    end
  end
end
