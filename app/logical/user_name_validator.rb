class UserNameValidator < ActiveModel::EachValidator
  def validate_each(rec, attr, value)
  	name = value

    rec.errors[attr] << "already exists" if User.find_by_name(name).present?
    rec.errors[attr] << "must be 2 to 20 characters long" if !name.length.between?(2, 20)
    rec.errors[attr] << "must contain only alphanumeric characters, hypens, apostrophes, tildes and underscores" unless name =~ /\A[a-zA-Z0-9\-_~']+\z/
    rec.errors[attr] << "must not begin with a special character" if name =~ /\A[_\-~']/
    rec.errors[attr] << "must not contain consecutive special characters" if name =~ /_{2}|-{2}|~{2}|'{2}/
    rec.errors[attr] << "cannot begin or end with an underscore" if name =~ /\A_|_\z/
    rec.errors[attr] << "cannot be the string 'me'" if name.downcase == 'me'
  end
end
