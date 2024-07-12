# frozen_string_literal: true

class SessionCreator
  attr_reader :session, :cookies, :name, :password, :ip_addr, :remember, :secure

  def initialize(session, cookies, name, password, ip_addr, remember = false, secure = false)
    @session = session
    @cookies = cookies
    @name = name
    @password = password
    @ip_addr = ip_addr
    @remember = remember
    @secure = secure
  end

  def authenticate
    if User.authenticate(name, password)
      user = User.find_by_name(name)

      session[:user_id] = user.id
      session[:ph] = user.password_token
      user.update_column(:last_ip_addr, ip_addr) unless user.is_blocked?

      if remember
        verifier = ActiveSupport::MessageVerifier.new(Danbooru.config.remember_key, serializer: JSON, digest: "SHA256")
        cookies.encrypted[:remember] = {value: verifier.generate("#{user.id}:#{user.password_token}", purpose: "rbr", expires_in: 14.days), expires: Time.now + 14.days, httponly: true, same_site: :lax, secure: Rails.env.production?}
      end
      return true
    else
      return false
    end
  end
end
