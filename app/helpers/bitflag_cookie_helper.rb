# frozen_string_literal: true

module BitflagCookieHelper
  INDEX = {
    hide_search_trends: 1,
    post_mobile_tab_state: 2,
    hide_post_recommendations: 3,
    hide_wiki_excerpt: 4,
  }.freeze

  # e6_prefs is a base2 cookie where each bit represents a different boolean preference.
  # Up to 31 preferences can be stored in a single cookie - excluding the sign bit.
  COOKIE_NAME = :e6_prefs

  def read_bitflag_cookie(name)
    index = INDEX[name]
    return false unless index

    (read_raw_bitflag_cookie & (1 << index)) != 0
  end

  def write_bitflag_cookie(name, value)
    index = INDEX[name]
    return unless index

    self.class.write_raw_bitflag_cookie(index, value)
  end

  # TODO: Untangle this after the migration period. See SessionLoader#populate_bitflag_cookie.
  def self.write_raw_bitflag_cookie(index, bit_value)
    raw_value = read_raw_bitflag_cookie
    if bit_value
      raw_value |= (1 << index)
    else
      raw_value &= ~(1 << index)
    end
    cookies[COOKIE_NAME] = { value: raw_value.to_s(2), expires: 1.year.from_now, httponly: true, same_site: :lax, secure: Rails.env.production? }
  end

  private

  def read_raw_bitflag_cookie
    (cookies[COOKIE_NAME] || "0").to_i(2)
  end
end
