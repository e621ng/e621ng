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
      user.update_column(:last_ip_addr, ip_addr)

      cookies.encrypted[:remember] = {value: user.id, expires: Time.now + 7.days, httponly: true} if remember
      return true
    else
      return false
    end
  end
end
