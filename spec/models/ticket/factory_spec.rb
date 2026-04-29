# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket do
  include_context "as member"

  describe "factory" do
    it "builds a valid default (user-type) ticket" do
      expect(build(:ticket)).to be_valid
    end

    it "builds a valid blip-type ticket" do
      expect(build(:ticket, :blip_type)).to be_valid
    end

    it "builds a valid comment-type ticket" do
      expect(build(:ticket, :comment_type)).to be_valid
    end

    it "builds a valid forum-type ticket" do
      expect(build(:ticket, :forum_type)).to be_valid
    end

    it "builds a valid pool-type ticket" do
      expect(build(:ticket, :pool_type)).to be_valid
    end

    it "builds a valid post-type ticket" do
      expect(build(:ticket, :post_type)).to be_valid
    end

    it "builds a valid set-type ticket" do
      expect(build(:ticket, :set_type)).to be_valid
    end

    it "builds a valid wiki-type ticket" do
      expect(build(:ticket, :wiki_type)).to be_valid
    end

    it "builds a valid replacement-type ticket" do
      expect(build(:ticket, :replacement_type)).to be_valid
    end
  end
end
