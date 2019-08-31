module UsersHelper
  def email_sig(user, purpose, expires = nil)
    EmailLinkValidator.generate("#{user.id}", purpose, expires)
  end
end
