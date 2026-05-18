# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostQueryBuilder do
  include_context "as admin"

  def run(query)
    PostQueryBuilder.new(query).search
  end

  describe "md5: metatag" do
    it "includes the post with the matching md5" do
      target = create(:post)
      target.update_columns(md5: "aabbccddeeff00112233445566778899")
      other = create(:post)
      other.update_columns(md5: "00112233445566778899aabbccddeeff")

      result = run("md5:aabbccddeeff00112233445566778899")
      expect(result).to include(target)
      expect(result).not_to include(other)
    end

    it "is case-insensitive (TagQuery lowercases the value)" do
      target = create(:post)
      target.update_columns(md5: "aabbccddeeff00112233445566778899")

      result = run("md5:AABBCCDDEEFF00112233445566778899")
      expect(result).to include(target)
    end
  end
end
