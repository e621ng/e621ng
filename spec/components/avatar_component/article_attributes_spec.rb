# frozen_string_literal: true

require "rails_helper"

RSpec.describe AvatarComponent do
  include_context "as member"

  let(:user) { create(:user) }

  def component(user = self.user)
    described_class.new(user: user)
  end

  describe "#article_attributes" do
    describe "css classes" do
      it "always includes the base classes" do
        classes = component.send(:article_attributes)[:class].split
        expect(classes).to include("thumbnail", "avatar", "no-stats", "placeholder")
      end

      it "includes no-render when user has no avatar" do
        expect(component.send(:article_attributes)[:class]).to include("no-render")
      end

      it "does not include no-render when user has an avatar" do
        post = create(:post)
        user_with_avatar = create(:user, avatar_id: post.id)
        expect(component(user_with_avatar).send(:article_attributes)[:class]).not_to include("no-render")
      end
    end

    describe "data attributes" do
      it "sets id to the user's avatar_id" do
        post = create(:post)
        user_with_avatar = create(:user, avatar_id: post.id)
        expect(component(user_with_avatar).send(:article_attributes).dig(:data, :id)).to eq(post.id)
      end

      it "sets id to nil when user has no avatar" do
        expect(component.send(:article_attributes).dig(:data, :id)).to be_nil
      end

      it "sets user-id to the user's id" do
        expect(component.send(:article_attributes).dig(:data, :"user-id")).to eq(user.id)
      end

      it "sets initial to the first letter of the username uppercased" do
        expect(component.send(:article_attributes).dig(:data, :initial)).to eq(user.name[0].upcase)
      end

      it "sets initial to ? when the username is blank" do
        allow(user).to receive(:name).and_return("")
        expect(component.send(:article_attributes).dig(:data, :initial)).to eq("?")
      end

      it "sets has-cropped-avatar to false by default" do
        expect(component.send(:article_attributes).dig(:data, :"has-cropped-avatar")).to be false
      end

      it "sets has-cropped-avatar to true when user has a cropped avatar" do
        user_with_crop = create(:user, has_cropped_avatar: true)
        expect(component(user_with_crop).send(:article_attributes).dig(:data, :"has-cropped-avatar")).to be true
      end
    end
  end
end
