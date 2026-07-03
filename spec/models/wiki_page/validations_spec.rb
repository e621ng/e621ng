# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           WikiPage Validations                              #
# --------------------------------------------------------------------------- #

RSpec.describe WikiPage do
  include_context "as admin"

  describe "validations" do
    # -------------------------------------------------------------------------
    # title — presence
    # -------------------------------------------------------------------------
    describe "title — presence" do
      it "is invalid when title is nil" do
        page = build(:wiki_page, title: nil)
        expect(page).not_to be_valid
        expect(page.errors[:title]).to be_present
      end

      it "is invalid when title is a blank string" do
        page = build(:wiki_page, title: "")
        expect(page).not_to be_valid
        expect(page.errors[:title]).to be_present
      end
    end

    # -------------------------------------------------------------------------
    # title — uniqueness (case-insensitive)
    # -------------------------------------------------------------------------
    describe "title — uniqueness" do
      it "is invalid when a page with the same lowercased title already exists" do
        create(:wiki_page, title: "duplicate_page")
        page = build(:wiki_page, title: "duplicate_page")
        expect(page).not_to be_valid
        expect(page.errors[:title]).to be_present
      end

      it "is invalid when the title differs only in case" do
        create(:wiki_page, title: "my_page")
        page = build(:wiki_page, title: "MY_PAGE")
        expect(page).not_to be_valid
        expect(page.errors[:title]).to be_present
      end

      it "does not treat the record as a duplicate of itself on update" do
        page = create(:wiki_page, title: "unique_page")
        page.body = "updated body"
        expect(page).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # title — length
    # -------------------------------------------------------------------------
    describe "title — length" do
      it "is invalid when title is exactly 101 characters" do
        page = build(:wiki_page, title: "a" * 101)
        expect(page).not_to be_valid
        expect(page.errors[:title]).to be_present
      end

      it "is valid when title is exactly 100 characters" do
        page = build(:wiki_page, title: "a" * 100)
        expect(page).to be_valid, page.errors.full_messages.join(", ")
      end
    end

    # -------------------------------------------------------------------------
    # title — tag_name format (only when title_changed?)
    # -------------------------------------------------------------------------
    describe "title — tag_name format" do
      it "is invalid when title begins with a dash" do
        page = build(:wiki_page, title: "-bad_title")
        expect(page).not_to be_valid
        expect(page.errors[:title]).to be_present
      end

      it "is invalid when title contains an asterisk" do
        page = build(:wiki_page, title: "bad*title")
        expect(page).not_to be_valid
        expect(page.errors[:title]).to be_present
      end

      it "is invalid when title contains a comma" do
        page = build(:wiki_page, title: "bad,title")
        expect(page).not_to be_valid
        expect(page.errors[:title]).to be_present
      end

      it "does not re-validate tag_name format when title is unchanged on update" do
        page = create(:wiki_page, title: "valid_title")
        # Corrupt the title in the DB to bypass creation validation, then confirm
        # updating another field (body) does not re-fire the format check.
        page.update_columns(title: "-corrupt_title")
        page.reload
        page.body = "updated body"
        expect(page).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # body — length
    # -------------------------------------------------------------------------
    describe "body — length" do
      it "is valid when body is exactly at the configured maximum" do
        page = build(:wiki_page, body: "a" * Danbooru.config.wiki_page_max_size)
        expect(page).to be_valid, page.errors.full_messages.join(", ")
      end

      it "is invalid when body exceeds the configured maximum by one character" do
        page = build(:wiki_page, body: "a" * (Danbooru.config.wiki_page_max_size + 1))
        expect(page).not_to be_valid
        expect(page.errors[:body]).to be_present
      end
    end

    # -------------------------------------------------------------------------
    # user_not_limited
    # -------------------------------------------------------------------------
    describe "user_not_limited" do
      it "is valid for an admin" do
        page = build(:wiki_page)
        expect(page).to be_valid, page.errors.full_messages.join(", ")
      end

      it "is valid for a privileged user" do
        CurrentUser.user = create(:privileged_user)
        page = build(:wiki_page)
        expect(page).to be_valid, page.errors.full_messages.join(", ")
      end

      it "is invalid for a user whose account is too new" do
        CurrentUser.user = create(:user, created_at: 1.day.ago)
        page = build(:wiki_page)
        expect(page).not_to be_valid
        expect(page.errors[:base]).to be_present
      end
    end

    # -------------------------------------------------------------------------
    # validate_not_locked
    # -------------------------------------------------------------------------
    describe "validate_not_locked" do
      let!(:locked_page) { create(:locked_wiki_page) }

      it "is invalid when the page is locked and CurrentUser is a member" do
        CurrentUser.user = create(:user)
        locked_page.body = "updated body"
        expect(locked_page).not_to be_valid
        expect(locked_page.errors[:is_locked]).to be_present
      end

      it "is valid when the page is locked and CurrentUser is a janitor" do
        CurrentUser.user = create(:janitor_user)
        locked_page.body = "updated body"
        expect(locked_page).to be_valid
      end

      it "is valid when the page is locked and CurrentUser is an admin" do
        locked_page.body = "updated body"
        expect(locked_page).to be_valid
      end

      it "is valid when the page is not locked and CurrentUser is a member" do
        CurrentUser.user = create(:user)
        page = build(:wiki_page, is_locked: false)
        expect(page).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # validate_rename
    # -------------------------------------------------------------------------
    describe "validate_rename" do
      it "is skipped entirely when title does not change" do
        page = create(:wiki_page, title: "stable_title")
        page.body = "updated body"
        expect(page).to be_valid
      end

      it "is invalid when the old tag has posts (skip_secondary_validations: false)" do
        page = create(:wiki_page, title: "tagged_page")
        create(:tag, name: "tagged_page", post_count: 5)
        page.title = "renamed_page"
        expect(page).not_to be_valid
        expect(page.errors[:title]).to be_present
      end

      it "is valid when old tag has posts but skip_secondary_validations is true" do
        page = create(:wiki_page, title: "tagged_page2")
        create(:tag, name: "tagged_page2", post_count: 5)
        page.title = "renamed_page2"
        page.skip_secondary_validations = true
        expect(page).to be_valid
      end

      it "is valid when the old tag has zero posts" do
        page = create(:wiki_page, title: "empty_tag_page")
        create(:tag, name: "empty_tag_page", post_count: 0)
        page.title = "empty_tag_renamed"
        expect(page).to be_valid
      end

      # -----------------------------------------------------------------------
      # validate_rename — HelpPage interaction
      # -----------------------------------------------------------------------
      it "is invalid for a non-admin renaming a wiki page used as a help page" do
        page = create(:wiki_page, title: "help_backed_page")
        create(:help_page, wiki: page, wiki_page: page.title)
        CurrentUser.user = create(:user)
        page.title = "help_backed_renamed"
        expect(page).not_to be_valid
        expect(page.errors[:title]).to include("is used as a help page and cannot be changed")
      end

      it "allows an admin to rename a wiki page used as a help page" do
        page = create(:wiki_page, title: "help_backed_page_admin")
        create(:help_page, wiki: page, wiki_page: page.title)
        page.title = "help_backed_renamed_admin"
        expect(page).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # validate_redirect
    # -------------------------------------------------------------------------
    describe "validate_redirect" do
      it "is skipped when parent does not change" do
        page = create(:wiki_page, title: "no_redir_page")
        page.body = "updated body"
        expect(page).to be_valid
      end

      it "is invalid when parent is set to a title that does not exist" do
        page = create(:wiki_page, title: "redirect_source")
        page.parent = "nonexistent_target"
        expect(page).not_to be_valid
        expect(page.errors[:parent]).to be_present
      end

      it "is valid when parent is set to the title of an existing wiki page" do
        create(:wiki_page, title: "redirect_target")
        page = create(:wiki_page, title: "redirect_source2")
        page.parent = "redirect_target"
        expect(page).to be_valid
      end

      it "is valid when parent is cleared (empty string is normalized to nil)" do
        create(:wiki_page, title: "some_target")
        page = create(:wiki_page, title: "was_redirect", parent: "some_target")
        page.parent = ""
        expect(page).to be_valid
      end

      # -----------------------------------------------------------------------
      # validate_redirect — HelpPage interaction
      # -----------------------------------------------------------------------
      it "is invalid when setting parent on a wiki page used as a help page" do
        target = create(:wiki_page, title: "redirect_target_hp")
        page   = create(:wiki_page, title: "help_redirect_source")
        create(:help_page, wiki: page, wiki_page: page.title)
        page.parent = target.title
        expect(page).not_to be_valid
        expect(page.errors[:title]).to include("is used as a help page and cannot be redirected")
      end
    end
  end
end
