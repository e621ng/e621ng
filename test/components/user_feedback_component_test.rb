# frozen_string_literal: true

require "test_helper"

class UserFeedbackComponentTest < ActionView::TestCase
  include FactoryBot::Syntax::Methods

  def setup
    @user = create(:user)
  end

  context "render?" do
    should "return true when user is present and style is valid" do
      component = UserFeedbackComponent.new(user: @user, style: :badge)
      assert component.render?
    end

    should "return true with inline style" do
      component = UserFeedbackComponent.new(user: @user, style: :inline)
      assert component.render?
    end

    should "return false when user is nil" do
      component = UserFeedbackComponent.new(user: nil, style: :badge)
      assert_not component.render?
    end

    should "convert style to symbol" do
      component = UserFeedbackComponent.new(user: @user, style: "badge")
      assert component.render?
    end

    should "default nil style to inline" do
      component = UserFeedbackComponent.new(user: @user, style: nil)
      assert component.render?
      assert_equal true, component.send(:inline_style?)
    end

    should "default invalid style to inline" do
      component = UserFeedbackComponent.new(user: @user, style: "invalid")
      assert component.render?
      assert_equal true, component.send(:inline_style?)
    end
  end

  context "style helpers" do
    should "correctly identify badge style" do
      component = UserFeedbackComponent.new(user: @user, style: :badge)
      assert_equal true, component.send(:badge_style?)
      assert_equal false, component.send(:inline_style?)
    end

    should "correctly identify inline style" do
      component = UserFeedbackComponent.new(user: @user, style: :inline)
      assert_equal false, component.send(:badge_style?)
      assert_equal true, component.send(:inline_style?)
    end
  end

  context "feedback calculation" do
    should "return positive feedback count" do
      as(create(:moderator_user)) do
        create(:user_feedback, user: @user, category: "positive")
        create(:user_feedback, user: @user, category: "positive")
      end
      component = UserFeedbackComponent.new(user: @user, style: :badge)

      assert_equal 2, component.send(:positive)
    end

    should "return neutral feedback count" do
      as(create(:moderator_user)) do
        create(:user_feedback, user: @user, category: "neutral")
      end
      component = UserFeedbackComponent.new(user: @user, style: :badge)

      assert_equal 1, component.send(:neutral)
    end

    should "return negative feedback count" do
      as(create(:moderator_user)) do
        create(:user_feedback, user: @user, category: "negative")
        create(:user_feedback, user: @user, category: "negative")
        create(:user_feedback, user: @user, category: "negative")
      end
      component = UserFeedbackComponent.new(user: @user, style: :badge)

      assert_equal 3, component.send(:negative)
    end

    should "return zero for categories with no feedback" do
      component = UserFeedbackComponent.new(user: @user, style: :badge)

      assert_equal 0, component.send(:positive)
      assert_equal 0, component.send(:neutral)
      assert_equal 0, component.send(:negative)
    end
  end

  context "deleted feedback visibility" do
    should "show deleted feedback count to staff users" do
      moderator = create(:moderator_user)
      as(moderator) do
        create(:user_feedback, user: @user, is_deleted: true)
        create(:user_feedback, user: @user, is_deleted: true)
      end

      as(create(:admin_user)) do
        component = UserFeedbackComponent.new(user: @user, style: :badge)
        assert_equal 2, component.send(:deleted)
      end
    end

    should "hide deleted feedback count from non-staff users" do
      moderator = create(:moderator_user)
      as(moderator) do
        create(:user_feedback, user: @user, is_deleted: true)
      end

      as(create(:user)) do
        component = UserFeedbackComponent.new(user: @user, style: :badge)
        assert_equal 0, component.send(:deleted)
      end
    end

    should "return zero deleted feedback when no deleted feedback exists" do
      component = UserFeedbackComponent.new(user: @user, style: :badge)
      assert_equal 0, component.send(:deleted)
    end
  end

  context "total calculations" do
    should "calculate active feedback correctly" do
      as(create(:moderator_user)) do
        create(:user_feedback, user: @user, category: "positive")
        create(:user_feedback, user: @user, category: "positive")
        create(:user_feedback, user: @user, category: "neutral")
        create(:user_feedback, user: @user, category: "negative")
      end

      component = UserFeedbackComponent.new(user: @user, style: :badge)

      assert_equal 4, component.send(:active)
    end

    should "calculate total including deleted feedback for staff" do
      as(create(:moderator_user)) do
        create(:user_feedback, user: @user, category: "positive")
        create(:user_feedback, user: @user, is_deleted: true)
      end

      as(create(:admin_user)) do
        component = UserFeedbackComponent.new(user: @user, style: :badge)
        assert_equal 2, component.send(:total)
      end
    end

    should "calculate total excluding deleted feedback for non-staff" do
      as(create(:moderator_user)) do
        create(:user_feedback, user: @user, category: "positive")
        create(:user_feedback, user: @user, is_deleted: true)
      end

      as(create(:user)) do
        component = UserFeedbackComponent.new(user: @user, style: :badge)
        assert_equal 1, component.send(:total)
      end
    end

    should "return zero total when no feedback exists" do
      component = UserFeedbackComponent.new(user: @user, style: :badge)

      assert_equal 0, component.send(:active)
      assert_equal 0, component.send(:total)
    end
  end

  context "badge style rendering" do
    should "render link with feedback data attributes when feedback exists" do
      moderator = create(:moderator_user)
      as(@user) do
        as(moderator) do
          create(:user_feedback, user: @user, category: "positive")
          create(:user_feedback, user: @user, category: "negative")
          create(:user_feedback, user: @user, category: "neutral")
        end
        render UserFeedbackComponent.new(user: @user, style: :badge)

        assert_select "a.user-records-list[data-positive='1'][data-negative='1'][data-neutral='1']"
      end
    end

    should "not render when no feedback exists" do
      as(@user) do
        render UserFeedbackComponent.new(user: @user, style: :badge)

        assert_select "a.user-records-list", count: 0
      end
    end

    should "include correct link path" do
      moderator = create(:moderator_user)
      as(@user) do
        as(moderator) do
          create(:user_feedback, user: @user, category: "positive")
        end
        render UserFeedbackComponent.new(user: @user, style: :badge)

        assert_select "a.user-records-list[href*='user_feedbacks']"
      end
    end
  end

  context "inline style rendering" do
    should "render feedback list with active feedback" do
      moderator = create(:moderator_user)
      as(@user) do
        as(moderator) do
          create(:user_feedback, user: @user, category: "positive")
          create(:user_feedback, user: @user, category: "negative")
        end
        render UserFeedbackComponent.new(user: @user, style: :inline)

        assert_select "a.user-feedback-list"
      end
    end

    should "not render when no active feedback exists" do
      as(@user) do
        render UserFeedbackComponent.new(user: @user, style: :inline)

        assert_select "a.user-feedback-list", count: 0
      end
    end

    should "include correct feedback count spans" do
      moderator = create(:moderator_user)
      as(@user) do
        as(moderator) do
          create(:user_feedback, user: @user, category: "positive")
          create(:user_feedback, user: @user, category: "positive")
          create(:user_feedback, user: @user, category: "negative")
        end
        render UserFeedbackComponent.new(user: @user, style: :inline)

        assert_select "span.user-feedback-positive", text: "2"
        assert_select "span.user-feedback-negative", text: "1"
      end
    end
  end
end
