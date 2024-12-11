# frozen_string_literal: true

class SessionCreator
  attr_reader :request, :session, :cookies, :name, :password, :remember

  def initialize(request, session, cookies, name, password, remember = false)
    @request = request
    @session = session
    @cookies = cookies
    @name = name
    @password = password
    @remember = remember
  end

  def authenticate
    if User.authenticate(name, password)
      user = User.find_by_name(name)

      session[:user_id] = user.id
      session[:last_authenticated_at] = Time.now.utc.to_s
      session[:ph] = user.password_token
      user.update_column(:last_ip_addr, request.remote_ip) unless user.is_blocked?

      if remember
        verifier = ActiveSupport::MessageVerifier.new(Danbooru.config.remember_key, serializer: JSON, digest: "SHA256")
        cookies.encrypted[:remember] = { value: verifier.generate("#{user.id}:#{user.password_token}", purpose: "rbr", expires_in: 14.days), expires: Time.now + 14.days, httponly: true, same_site: :lax, secure: Rails.env.production? }
      end
      return true
    else
      return false
    end
  end
end
