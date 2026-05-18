# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          PostSet Validations                                #
# --------------------------------------------------------------------------- #

RSpec.describe PostSet do
  include_context "as member"

  # -------------------------------------------------------------------------
  # name — length
  # -------------------------------------------------------------------------
  describe "name — length" do
    it "is invalid when name is fewer than 3 characters" do
      set = build(:post_set, name: "ab")
      expect(set).not_to be_valid
      expect(set.errors[:name]).to be_present
    end

    it "is invalid when name exceeds 100 characters" do
      set = build(:post_set, name: "a" * 101)
      expect(set).not_to be_valid
      expect(set.errors[:name]).to be_present
    end

    it "is valid at exactly 3 characters" do
      set = build(:post_set, name: "abc", shortname: "abc")
      expect(set).to be_valid, set.errors.full_messages.join(", ")
    end

    it "is valid at exactly 100 characters" do
      set = build(:post_set, name: "a" * 100)
      expect(set).to be_valid, set.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # name — uniqueness (case-insensitive)
  # -------------------------------------------------------------------------
  describe "name — uniqueness" do
    it "is invalid when a set with the same name already exists" do
      create(:post_set, name: "Duplicate Set")
      set = build(:post_set, name: "Duplicate Set")
      expect(set).not_to be_valid
      expect(set.errors[:name]).to be_present
    end

    it "is invalid when names differ only in case" do
      create(:post_set, name: "My Set")
      set = build(:post_set, name: "my set")
      expect(set).not_to be_valid
      expect(set.errors[:name]).to be_present
    end

    it "does not treat the record as a duplicate of itself on update" do
      set = create(:post_set, name: "Unique Set Name")
      set.description = "updated"
      expect(set).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # shortname — length
  # -------------------------------------------------------------------------
  describe "shortname — length" do
    it "is invalid when shortname is fewer than 3 characters" do
      set = build(:post_set, shortname: "ab")
      expect(set).not_to be_valid
      expect(set.errors[:shortname]).to be_present
    end

    it "is invalid when shortname exceeds 50 characters" do
      set = build(:post_set, shortname: "a" * 51)
      expect(set).not_to be_valid
      expect(set.errors[:shortname]).to be_present
    end

    it "is valid at exactly 3 characters" do
      set = build(:post_set, shortname: "abc")
      expect(set).to be_valid, set.errors.full_messages.join(", ")
    end

    it "is valid at exactly 50 characters" do
      set = build(:post_set, shortname: "#{'a' * 49}b")
      expect(set).to be_valid, set.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # shortname — format: word characters only
  # -------------------------------------------------------------------------
  describe "shortname — word characters only" do
    it "is invalid when shortname contains a space" do
      set = build(:post_set, shortname: "bad name")
      expect(set).not_to be_valid
      expect(set.errors[:shortname]).to be_present
    end

    it "is invalid when shortname contains a hyphen" do
      set = build(:post_set, shortname: "bad-name")
      expect(set).not_to be_valid
      expect(set.errors[:shortname]).to be_present
    end

    it "is valid with letters, digits, and underscores" do
      set = build(:post_set, shortname: "valid_name_1")
      expect(set).to be_valid, set.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # shortname — must contain a lowercase letter or underscore
  # -------------------------------------------------------------------------
  describe "shortname — must contain lowercase letter or underscore" do
    it "is invalid when shortname is all digits" do
      set = build(:post_set, shortname: "123")
      expect(set).not_to be_valid
      expect(set.errors[:shortname]).to be_present
    end

    it "is valid when shortname starts with a digit but contains a lowercase letter" do
      set = build(:post_set, shortname: "1abc")
      expect(set).to be_valid, set.errors.full_messages.join(", ")
    end

    it "is valid when shortname starts with an underscore" do
      set = build(:post_set, shortname: "_abc")
      expect(set).to be_valid, set.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # shortname — uniqueness (case-insensitive)
  # -------------------------------------------------------------------------
  describe "shortname — uniqueness" do
    it "is invalid when a set with the same shortname already exists" do
      create(:post_set, shortname: "taken_name")
      set = build(:post_set, shortname: "taken_name")
      expect(set).not_to be_valid
      expect(set.errors[:shortname]).to be_present
    end

    it "does not treat the record as a duplicate of itself on update" do
      set = create(:post_set, shortname: "unique_sname")
      set.description = "updated"
      expect(set).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # description — max length
  # -------------------------------------------------------------------------
  describe "description — max length" do
    it "is invalid when description exceeds the configured maximum" do
      set = build(:post_set, description: "a" * (Danbooru.config.pool_descr_max_size + 1))
      expect(set).not_to be_valid
      expect(set.errors[:description]).to be_present
    end

    it "is valid at exactly the configured maximum" do
      set = build(:post_set, description: "a" * Danbooru.config.pool_descr_max_size)
      expect(set).to be_valid, set.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # validate_number_of_posts
  # -------------------------------------------------------------------------
  describe "validate_number_of_posts" do
    it "is invalid when post_ids exceed the configured limit" do
      max = Danbooru.config.post_set_post_limit.to_i
      set = create(:post_set)
      # Directly set post_ids above limit via the attribute writer to trigger validation
      set.post_ids = Array.new(max + 1) { |i| i + 1 }
      expect(set).not_to be_valid
      expect(set.errors[:base]).to be_present
    end

    it "is valid when post_ids equal the configured limit" do
      set = create(:post_set)
      # Stub max_posts to a small value so the test doesn't need max real IDs
      allow(set).to receive(:max_posts).and_return(3)
      set.post_ids = [1, 2, 3]
      expect(set).to be_valid, set.errors.full_messages.join(", ")
    end

    it "does not trigger when no new post_ids are added" do
      set = create(:post_set)
      set.description = "change only"
      expect(set).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # can_make_public — account age restriction
  # -------------------------------------------------------------------------
  describe "can_make_public" do
    it "is invalid when a new account (< 3 days old) tries to make a set public" do
      new_user = create(:user, created_at: 1.day.ago)
      CurrentUser.user = new_user
      set = build(:post_set, creator: new_user, is_public: true)
      expect(set).not_to be_valid
      expect(set.errors[:base]).to be_present
    end

    it "is valid when an established account (>= 3 days old) makes a set public" do
      set = build(:post_set, creator: CurrentUser.user, is_public: true)
      expect(set).to be_valid, set.errors.full_messages.join(", ")
    end

    it "does not fire when is_public is not changed" do
      set = create(:post_set, is_public: false)
      set.description = "noop"
      expect(set).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # set_per_hour_limit — on create
  # -------------------------------------------------------------------------
  describe "set_per_hour_limit" do
    it "is invalid when a member has already created more than 6 sets in the last hour" do
      creator = CurrentUser.user
      # Create 7 sets for the same creator to hit the limit (> 6)
      7.times { create(:post_set, creator: creator) }
      set = build(:post_set, creator: creator)
      expect(set).not_to be_valid
      expect(set.errors[:base]).to be_present
    end

    it "is valid for a janitor even after exceeding the hourly limit" do
      janitor = create(:janitor_user)
      CurrentUser.user = janitor
      7.times { create(:post_set, creator: janitor) }
      set = build(:post_set, creator: janitor)
      expect(set).to be_valid, set.errors.full_messages.join(", ")
    end
  end

  # -------------------------------------------------------------------------
  # can_create_new_set_limit — on create
  # -------------------------------------------------------------------------
  describe "can_create_new_set_limit" do
    it "is invalid when the user already owns 75 sets" do
      # Bypass callbacks/limits to seed the DB quickly
      creator = CurrentUser.user
      PostSet.insert_all!(
        75.times.map do |i|
          {
            name:            "Bulk Set #{i}",
            shortname:       "bulk_set_#{i}",
            creator_id:      creator.id,
            creator_ip_addr: "127.0.0.1",
            post_ids:        [],
            post_count:      0,
            created_at:      Time.current,
            updated_at:      Time.current,
          }
        end,
      )
      set = build(:post_set, creator: creator)
      expect(set).not_to be_valid
      expect(set.errors[:base]).to be_present
    end
  end
end
