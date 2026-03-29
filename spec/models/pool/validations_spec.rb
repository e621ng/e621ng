# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                            Pool Validations                                 #
# --------------------------------------------------------------------------- #

RSpec.describe Pool do
  # -------------------------------------------------------------------------
  # name — uniqueness (case-insensitive)
  # -------------------------------------------------------------------------
  describe "name — uniqueness" do
    include_context "as admin"

    it "is invalid when a pool with the same name already exists" do
      create(:pool, name: "duplicate_pool")
      pool = build(:pool, name: "duplicate_pool")
      expect(pool).not_to be_valid
      expect(pool.errors[:name]).to be_present
    end

    it "is invalid when names differ only in case" do
      create(:pool, name: "my_pool")
      pool = build(:pool, name: "MY_POOL")
      expect(pool).not_to be_valid
      expect(pool.errors[:name]).to be_present
    end

    it "does not treat the record as a duplicate of itself on update" do
      pool = create(:pool, name: "unique_pool")
      pool.description = "updated"
      expect(pool).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # name — length
  # -------------------------------------------------------------------------
  describe "name — length" do
    include_context "as admin"

    it "is invalid with an empty name" do
      pool = build(:pool, name: "")
      expect(pool).not_to be_valid
      expect(pool.errors[:name]).to be_present
    end

    it "is invalid when name exceeds 250 characters" do
      pool = build(:pool, name: "a" * 251)
      expect(pool).not_to be_valid
      expect(pool.errors[:name]).to be_present
    end

    it "is valid at exactly 250 characters" do
      pool = build(:pool, name: "a" * 250)
      expect(pool).to be_valid, pool.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # name — reserved words and forbidden patterns
  # -------------------------------------------------------------------------
  describe "name — forbidden values" do
    include_context "as admin"

    %w[any none series collection].each do |reserved|
      it "is invalid when name is the reserved word '#{reserved}'" do
        pool = build(:pool, name: reserved)
        expect(pool).not_to be_valid
        expect(pool.errors[:name]).to be_present
      end

      it "is invalid when name is the reserved word '#{reserved}' in uppercase" do
        pool = build(:pool, name: reserved.upcase)
        expect(pool).not_to be_valid
        expect(pool.errors[:name]).to be_present
      end
    end

    it "is invalid when name contains an asterisk" do
      pool = build(:pool, name: "pool*name")
      expect(pool).not_to be_valid
      expect(pool.errors[:name]).to be_present
    end

    it "is invalid when name consists only of digits" do
      pool = build(:pool, name: "12345")
      expect(pool).not_to be_valid
      expect(pool.errors[:name]).to be_present
    end

    it "is invalid when name contains a comma" do
      pool = build(:pool, name: "pool,name")
      expect(pool).not_to be_valid
      expect(pool.errors[:name]).to be_present
    end

    it "is invalid when name contains consecutive hyphens" do
      pool = build(:pool, name: "pool--name")
      expect(pool).not_to be_valid
      expect(pool.errors[:name]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # description — max length
  # -------------------------------------------------------------------------
  describe "description — length" do
    include_context "as admin"

    it "is invalid when description exceeds the configured maximum" do
      pool = build(:pool, description: "a" * (Danbooru.config.pool_descr_max_size + 1))
      expect(pool).not_to be_valid
      expect(pool.errors[:description]).to be_present
    end

    it "is valid at exactly the configured maximum" do
      pool = build(:pool, description: "a" * Danbooru.config.pool_descr_max_size)
      expect(pool).to be_valid, pool.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # category — inclusion
  # -------------------------------------------------------------------------
  describe "category — inclusion" do
    include_context "as admin"

    it "is valid with category 'series'" do
      pool = build(:pool, category: "series")
      expect(pool).to be_valid, pool.errors.full_messages.join(", ")
    end

    it "is valid with category 'collection'" do
      pool = build(:pool, category: "collection")
      expect(pool).to be_valid, pool.errors.full_messages.join(", ")
    end

    it "is invalid with an unrecognised category" do
      pool = build(:pool, category: "anthology")
      expect(pool).not_to be_valid
      expect(pool.errors[:category]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # user_not_create_limited (on: :create)
  # -------------------------------------------------------------------------
  describe "user_not_create_limited" do
    it "rejects creation by a member who signed up less than 7 days ago" do
      new_member = create(:user, created_at: 1.day.ago)
      CurrentUser.user = new_member
      CurrentUser.ip_addr = "127.0.0.1"

      pool = build(:pool)
      expect(pool).not_to be_valid
      expect(pool.errors[:creator]).to be_present

      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    it "allows creation by a member older than 7 days" do
      old_member = create(:user, created_at: 8.days.ago)
      CurrentUser.user = old_member
      CurrentUser.ip_addr = "127.0.0.1"

      pool = build(:pool)
      expect(pool).to be_valid, pool.errors.full_messages.join(", ")

      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    it "allows creation by a janitor regardless of age" do
      new_janitor = create(:janitor_user, created_at: 1.day.ago)
      CurrentUser.user = new_janitor
      CurrentUser.ip_addr = "127.0.0.1"

      pool = build(:pool)
      expect(pool).to be_valid, pool.errors.full_messages.join(", ")

      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    it "rejects creation when the pool rate limit is exceeded" do
      old_member = create(:user, created_at: 30.days.ago)
      CurrentUser.user = old_member
      CurrentUser.ip_addr = "127.0.0.1"

      # Exhaust the hourly pool limit (default: 5) by creating that many pools
      Danbooru.config.pool_limit.times { create(:pool) }

      pool = build(:pool)
      expect(pool).not_to be_valid
      expect(pool.errors[:creator]).to be_present

      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end
  end

  # -------------------------------------------------------------------------
  # user_not_limited (on: :update)
  # -------------------------------------------------------------------------
  describe "user_not_limited" do
    include_context "as admin"

    it "rejects an update by a member who signed up less than 3 days ago" do
      pool = create(:pool)

      new_member = create(:user, created_at: 1.day.ago)
      CurrentUser.user = new_member
      CurrentUser.ip_addr = "127.0.0.1"

      pool.description = "changed"
      expect(pool).not_to be_valid
      expect(pool.errors[:updater]).to be_present
    end

    it "rejects an update when the pool edit limit is exceeded" do
      pool = create(:pool)

      old_member = create(:user, created_at: 30.days.ago)
      CurrentUser.user = old_member
      CurrentUser.ip_addr = "127.0.0.1"

      allow(old_member).to receive(:pool_edit_limit).and_return(0)

      pool.description = "changed"
      expect(pool).not_to be_valid
      expect(pool.errors[:updater]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # user_not_posts_limited (on: :update, if: post_ids_changed?)
  # -------------------------------------------------------------------------
  describe "user_not_posts_limited" do
    include_context "as admin"

    it "rejects a post_ids change by a member who signed up less than 7 days ago" do
      pool = create(:pool, post_ids: [1])

      new_member = create(:user, created_at: 1.day.ago)
      CurrentUser.user = new_member
      CurrentUser.ip_addr = "127.0.0.1"

      pool.post_ids = [1, 2]
      expect(pool).not_to be_valid
      expect(pool.errors[:updater]).to be_present
    end

    it "rejects a post_ids change when the pool post edit limit is exceeded" do
      pool = create(:pool, post_ids: [1])

      old_member = create(:user, created_at: 30.days.ago)
      CurrentUser.user = old_member
      CurrentUser.ip_addr = "127.0.0.1"

      allow(old_member).to receive(:pool_post_edit_limit).and_return(0)

      pool.post_ids = [1, 2]
      expect(pool).not_to be_valid
      expect(pool.errors[:updater]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # updater_can_change_category (on: :update)
  # -------------------------------------------------------------------------
  describe "updater_can_change_category" do
    it "blocks a member from changing category when post_count exceeds the limit" do
      limit = Danbooru.config.pool_category_change_limit
      admin = create(:admin_user)
      pool = CurrentUser.scoped(admin, "127.0.0.1") do
        create(:pool, post_ids: (1..(limit + 1)).to_a, skip_sync: true)
      end

      member = create(:user)
      CurrentUser.user = member
      CurrentUser.ip_addr = "127.0.0.1"

      pool.category = pool.category == "series" ? "collection" : "series"
      expect(pool).not_to be_valid
      expect(pool.errors[:base].join).to include("cannot change the category")

      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    it "allows a janitor to change category regardless of post count" do
      limit = Danbooru.config.pool_category_change_limit
      admin = create(:admin_user)
      pool = CurrentUser.scoped(admin, "127.0.0.1") do
        create(:pool, post_ids: (1..(limit + 1)).to_a, skip_sync: true)
      end

      janitor = create(:janitor_user)
      CurrentUser.user = janitor
      CurrentUser.ip_addr = "127.0.0.1"

      pool.category = pool.category == "series" ? "collection" : "series"
      expect(pool).to be_valid, pool.errors.full_messages.join(", ")

      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    it "allows a member to change category when post_count is within the limit" do
      member = create(:user)
      pool = CurrentUser.scoped(member, "127.0.0.1") { create(:pool, post_ids: [1]) }

      CurrentUser.user = member
      CurrentUser.ip_addr = "127.0.0.1"

      pool.category = pool.category == "series" ? "collection" : "series"
      expect(pool).to be_valid, pool.errors.full_messages.join(", ")

      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end
  end

  # -------------------------------------------------------------------------
  # updater_can_remove_posts
  # -------------------------------------------------------------------------
  describe "updater_can_remove_posts" do
    it "blocks a new member (< 7 days old) from removing posts" do
      admin = create(:admin_user)
      pool = CurrentUser.scoped(admin, "127.0.0.1") do
        create(:pool, post_ids: [1, 2, 3], skip_sync: true)
      end

      new_member = create(:user, created_at: 1.day.ago)
      CurrentUser.user = new_member
      CurrentUser.ip_addr = "127.0.0.1"

      pool.post_ids = [1]
      expect(pool).not_to be_valid
      expect(pool.errors[:base].join).to include("cannot removes posts from pools")

      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    it "allows an established member (>= 7 days old) to remove posts" do
      old_member = create(:user, created_at: 8.days.ago)
      pool = CurrentUser.scoped(old_member, "127.0.0.1") do
        create(:pool, post_ids: [1, 2, 3], skip_sync: true)
      end

      CurrentUser.user = old_member
      CurrentUser.ip_addr = "127.0.0.1"

      pool.post_ids = [1]
      expect(pool).to be_valid, pool.errors.full_messages.join(", ")

      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end
  end

  # -------------------------------------------------------------------------
  # validate_number_of_posts
  # -------------------------------------------------------------------------
  describe "validate_number_of_posts" do
    include_context "as admin"

    it "is invalid when adding posts would exceed the pool post limit" do
      max = Danbooru.config.pool_post_limit(CurrentUser.user)
      existing_ids = (1..(max - 1)).to_a
      pool = create(:pool, post_ids: existing_ids, skip_sync: true)

      # Adding 2 more pushes over the limit
      pool.post_ids = existing_ids + [max, max + 1]
      expect(pool).not_to be_valid
      expect(pool.errors[:base].join).to include("Pools can only have up to")
    end

    it "is valid when the total stays at or below the limit" do
      max = Danbooru.config.pool_post_limit(CurrentUser.user)
      existing_ids = (1..(max - 1)).to_a
      pool = create(:pool, post_ids: existing_ids, skip_sync: true)

      pool.post_ids = existing_ids + [max]
      expect(pool).to be_valid, pool.errors.full_messages.join(", ")
    end
  end
end
