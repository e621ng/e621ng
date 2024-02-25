# frozen_string_literal: true

require "test_helper"

class LinkHelperTest < ActionView::TestCase
  test "for a non-handled url" do
    assert_equal(LinkHelper::NONE, hostname_for_link("https://example.com"))
  end

  test "for a invalid url" do
    assert_equal(LinkHelper::NONE, hostname_for_link("https:example.com"))
  end

  test "for a non-url" do
    assert_equal(LinkHelper::NONE, hostname_for_link("text"))
  end

  test "for a normal domain" do
    assert_equal("e621.net", hostname_for_link("https://e621.net"))
    assert_equal("e621.net", hostname_for_link("https://www.e621.net"))

    assert_equal("imgur.com", hostname_for_link("https://imgur.com"))
    assert_equal("imgur.com", hostname_for_link("https://www.imgur.com"))
  end

  test "for a domain with aliases" do
    assert_equal("discord.com", hostname_for_link("https://discordapp.com"))
    assert_equal("furaffinity.net", hostname_for_link("https://d.facdn.net"))

    assert_equal("inkbunny.net", hostname_for_link("https://ib.metapix.net"))
    assert_equal("inkbunny.net", hostname_for_link("https://qb.ib.metapix.net"))
  end

  test "all listed images exist" do
    favicon_folder = Rails.public_path.join("images/favicons")
    all_domains = LinkHelper::DECORATABLE_DOMAINS + LinkHelper::DECORATABLE_ALIASES.values + [LinkHelper::NONE]
    all_domains.each do |domain|
      assert(favicon_folder.join("#{domain}.png").exist?, "missing #{domain}")
    end
    # No extraneous files
    all_files = favicon_folder.children.map { |file| file.basename.to_s.delete_suffix(".png") }
    assert_empty(all_files - all_domains, "unused files in favicon folder")
  end
end
