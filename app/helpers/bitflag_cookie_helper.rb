# frozen_string_literal: true

module BitflagCookieHelper
  def read_bitflag_cookie(name)
    BitflagCookie.new(cookies).read(name)
  end

  def write_bitflag_cookie(name, value)
    BitflagCookie.new(cookies).write(name, value)
  end
end
