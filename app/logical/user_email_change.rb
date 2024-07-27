# frozen_string_literal: true

class UserEmailChange
  attr_reader :user, :password, :new_email

  def initialize(user, new_email, password)
    @user = user
    @new_email = new_email
    @password = password
  end

  def process
    if user.is_blocked?
      raise ::User::PrivilegeError.new("Cannot change email while banned")
    end

    if RateLimiter.check_limit("email:#{user.id}", 2, 24.hours)
      user.errors.add(:base, "Email changed too recently")
      return
    end

    if User.authenticate(user.name, password).nil?
      user.errors.add(:base, "Password was incorrect")
    else
      user.validate_email_format = true
      user.email = new_email
      user.email_verification_key = '1' if Danbooru.config.enable_email_verification?
      user.save

      if user.errors.empty?
        RateLimiter.hit("email:#{user.id}", 24.hours)
        if Danbooru.config.enable_email_verification?
          Maintenance::User::EmailConfirmationMailer.confirmation(user).deliver_now
        end
      end
    end
  end
end
