# frozen_string_literal: true

class UserNameValidator < ActiveModel::EachValidator
  def validate_each(rec, attr, value)
    name = value

    rec.errors.add(attr, "already exists") if User.find_by_name(name).present?
    rec.errors.add(attr, "must be 2 to 20 characters long") if !name.length.between?(2, 20)
    rec.errors.add(attr, "must contain only alphanumeric characters, hypens, apostrophes, tildes and underscores") unless name =~ /\A[a-zA-Z0-9\-_~']+\z/
    rec.errors.add(attr, "must not begin with a special character") if name =~ /\A[_\-~']/
    rec.errors.add(attr, "must not contain consecutive special characters") if name =~ /_{2}|-{2}|~{2}|'{2}/
    rec.errors.add(attr, "cannot begin or end with an underscore") if name =~ /\A_|_\z/
    rec.errors.add(attr, "cannot consist of numbers only") if name =~ /\A[0-9]+\z/
    rec.errors.add(attr, "cannot be the string 'me'") if name.downcase == 'me'
  end
end
