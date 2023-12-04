class CurrentUser
  def self.scoped(user, ip_addr = "127.0.0.1")
    old_user = self.user
    old_ip_addr = self.ip_addr

    self.user = user
    self.ip_addr = ip_addr

    begin
      yield
    ensure
      self.user = old_user
      self.ip_addr = old_ip_addr
    end
  end

  def self.as_system(&)
    scoped(::User.system, &)
  end

  def self.user=(user)
    RequestStore[:current_user] = user
  end

  def self.ip_addr=(ip_addr)
    RequestStore[:current_ip_addr] = ip_addr
  end

  def self.user
    RequestStore[:current_user]
  end

  def self.ip_addr
    RequestStore[:current_ip_addr]
  end

  def self.id
    if user.nil?
      nil
    else
      user.id
    end
  end

  def self.name
    user.name
  end

  def self.safe_mode?
    RequestStore[:safe_mode]
  end

  def self.safe_mode=(safe_mode)
    RequestStore[:safe_mode] = safe_mode
  end

  def self.method_missing(method, *, &)
    user.__send__(method, *, &)
  end
end
