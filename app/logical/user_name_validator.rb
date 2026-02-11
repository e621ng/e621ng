# frozen_string_literal: true

class UserNameValidator < ActiveModel::EachValidator
  def validate_each(rec, attr, value)
    name = value

    # For User model, check against rec.id
    # For other models (like UserNameChangeRequest), check against the user_id option
    user_id = rec.is_a?(User) ? rec.id : options[:user_id]&.call(rec)

    lookup = User.find_by_name(name) # rubocop:disable Rails/DynamicFindBy
    if lookup.present?
      if lookup.id != user_id
        rec.errors.add(attr, "already exists")
      elsif lookup.name == name
        rec.errors.add(attr, "is the same as your current name")
      end
    end
    rec.errors.add(attr, "must be 2 to 20 characters long") unless name.length.between?(2, 20)
    rec.errors.add(attr, "must contain only alphanumeric characters, hyphens, apostrophes, tildes and underscores") unless name =~ /\A[a-zA-Z0-9\-_~']+\z/
    rec.errors.add(attr, "must not begin with a special character") if name =~ /\A[_\-~']/
    rec.errors.add(attr, "must not contain consecutive special characters") if name =~ /_{2}|-{2}|~{2}|'{2}/
    rec.errors.add(attr, "cannot begin or end with an underscore") if name =~ /\A_|_\z/
    rec.errors.add(attr, "cannot consist of numbers only") if name =~ /\A[0-9]+\z/
    rec.errors.add(attr, "cannot be one of the reserved words") if %w[me home settings].include?(name.downcase)
  end
end
