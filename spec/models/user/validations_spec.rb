# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                               Basic Validations                             #
# --------------------------------------------------------------------------- #

RSpec.describe User do
  subject(:user) { build(:user) }

  # -------------------------------------------------------------------------
  # Validations
  # -------------------------------------------------------------------------
  describe "validations" do
    it "is invalid without a name" do
      new_user = build(:user, name: nil)
      expect(new_user).not_to be_valid
      expect(new_user.errors[:name]).to include("can't be blank")

      normal_user = build(:user)
      expect(normal_user).to be_valid
      normal_user.name = nil
      expect(normal_user).not_to be_valid
      expect(normal_user.errors[:name]).to include("can't be blank")
    end

    # Name format and uniqueness rules are tested in spec/logical/user_name_validator_spec.rb

    describe "default_image_size" do
      it "is invalid with an unrecognised value" do
        user = build(:user, default_image_size: "huge")
        expect(user).not_to be_valid
        expect(user.errors[:default_image_size]).to be_present
      end

      it "is valid with each accepted value" do
        %w[large fit fitv original].each do |size|
          user = build(:user, default_image_size: size)
          expect(user).to be_valid, "expected '#{size}' to be valid"
        end
      end
    end

    describe "per_page" do
      it "is invalid when below 1" do
        user = build(:user, per_page: 0)
        expect(user).not_to be_valid
        expect(user.errors[:per_page]).to be_present
      end

      it "is invalid when above 320" do
        user = build(:user, per_page: 321)
        expect(user).not_to be_valid
        expect(user.errors[:per_page]).to be_present
      end

      it "is valid at the boundaries" do
        expect(build(:user, per_page: 1)).to be_valid
        expect(build(:user, per_page: 320)).to be_valid
      end
    end

    describe "comment_threshold" do
      it "is invalid without a value" do
        user = build(:user, comment_threshold: nil)
        expect(user).not_to be_valid
        expect(user.errors[:comment_threshold]).to include("can't be blank")
      end

      it "is invalid when not an integer" do
        user = build(:user, comment_threshold: 1.5)
        expect(user).not_to be_valid
        expect(user.errors[:comment_threshold]).to be_present
      end

      it "is invalid when 50,000 or greater" do
        user = build(:user, comment_threshold: 50_000)
        expect(user).not_to be_valid
        user2 = build(:user, comment_threshold: 50_001)
        expect(user2).not_to be_valid
      end

      it "is invalid when -50,000 or less" do
        user = build(:user, comment_threshold: -50_000)
        expect(user).not_to be_valid
        user2 = build(:user, comment_threshold: -50_001)
        expect(user2).not_to be_valid
      end

      it "is valid within bounds" do
        expect(build(:user, comment_threshold: 0)).to be_valid
        expect(build(:user, comment_threshold: 49_999)).to be_valid
        expect(build(:user, comment_threshold: -49_999)).to be_valid
      end
    end

    describe "password" do
      it "is invalid when shorter than 8 characters on create" do
        user = build(:user, password: "short", password_confirmation: "short")
        expect(user).not_to be_valid
        expect(user.errors[:password]).to be_present
      end

      it "is invalid when the confirmation does not match" do
        user = build(:user, password: "hexerade1234", password_confirmation: "different1234")
        expect(user).not_to be_valid
        expect(user.errors[:password_confirmation]).to be_present
      end

      it "is invalid when the password_confirmation is absent on create" do
        user = build(:user, password: "hexerade1234", password_confirmation: nil)
        expect(user).not_to be_valid
        expect(user.errors[:password_confirmation]).to be_present
      end

      it "is invalid when the password is insecure" do
        user = build(:user, password: "password", password_confirmation: "password")
        expect(user).not_to be_valid
        expect(user.errors[:password]).to be_present
      end

      it "does not revalidate password when neither password nor old_password is given on update" do
        # Reload clears the attr_accessor values set by the factory (password / password_confirmation)
        user = create(:user).reload
        user.comment_threshold = 0
        expect(user).to be_valid
      end
    end

    describe "blacklisted_tags" do
      it "is invalid when exceeding 150,000 characters" do
        user = build(:user, blacklisted_tags: "a" * 150_001)
        expect(user).not_to be_valid
        expect(user.errors[:blacklisted_tags]).to be_present
      end

      it "is valid at exactly 150,000 characters" do
        user = build(:user, blacklisted_tags: "a" * 150_000)
        expect(user).to be_valid
      end
    end

    describe "custom_style" do
      it "is invalid when exceeding 500,000 characters" do
        user = build(:user, custom_style: "a" * 500_001)
        expect(user).not_to be_valid
        expect(user.errors[:custom_style]).to be_present
      end

      it "is valid at exactly 500,000 characters" do
        user = build(:user, custom_style: "a" * 500_000)
        expect(user).to be_valid
      end
    end

    describe "profile_about" do
      it "is invalid when exceeding the configured maximum" do
        user = build(:user, profile_about: "a" * (Danbooru.config.user_about_max_size + 1))
        expect(user).not_to be_valid
        expect(user.errors[:profile_about]).to be_present
      end

      it "is valid at exactly the configured maximum" do
        user = build(:user, profile_about: "a" * Danbooru.config.user_about_max_size)
        expect(user).to be_valid
      end
    end

    describe "profile_artinfo" do
      it "is invalid when exceeding the configured maximum" do
        user = build(:user, profile_artinfo: "a" * (Danbooru.config.user_about_max_size + 1))
        expect(user).not_to be_valid
        expect(user.errors[:profile_artinfo]).to be_present
      end

      it "is valid at exactly the configured maximum" do
        user = build(:user, profile_artinfo: "a" * Danbooru.config.user_about_max_size)
        expect(user).to be_valid
      end
    end

    describe "custom title" do
      it "is invalid when exceeding 100 characters" do
        user = build(:user, custom_title: "a" * 101)
        expect(user).not_to be_valid
        expect(user.errors[:custom_title]).to be_present
      end

      it "is valid at exactly 100 characters" do
        user = build(:user, custom_title: "a" * 100)
        expect(user).to be_valid
      end

      it "is valid when blank" do
        user = build(:user, custom_title: "")
        expect(user).to be_valid
      end

      it "is valid when nil" do
        user = build(:user, custom_title: nil)
        expect(user).to be_valid
      end
    end

    describe "time_zone" do
      it "is invalid with an unrecognised time zone" do
        user = build(:user, time_zone: "Not/ATimezone")
        expect(user).not_to be_valid
        expect(user.errors[:time_zone]).to be_present
      end

      it "is valid with a recognised time zone" do
        user = build(:user, time_zone: "UTC")
        expect(user).to be_valid
      end
    end

    describe "IP ban check (on create)" do
      after { CurrentUser.ip_addr = nil }

      it "is invalid when the current IP address is banned" do
        banned_ip = "1.2.3.4"
        admin = create(:admin_user)
        CurrentUser.scoped(admin) { IpBan.create!(ip_addr: banned_ip, reason: "test") }
        CurrentUser.ip_addr = banned_ip

        user = build(:user)
        expect(user).not_to be_valid
        expect(user.errors[:base]).to include("IP address is banned")
      end

      it "is valid when the current IP address is not banned" do
        CurrentUser.ip_addr = "5.6.7.8"
        user = build(:user)
        expect(user).to be_valid
      end
    end

    describe "sock puppet check (on create)" do
      after { CurrentUser.ip_addr = nil }

      it "is invalid when the same IP was used to create an account recently" do
        shared_ip = "10.0.0.1"
        # created_at must be within the last day for the sock puppet check to trigger
        create(:user, last_ip_addr: shared_ip, created_at: 1.hour.ago)
        CurrentUser.ip_addr = shared_ip

        new_user = build(:user, disable_sock_puppet_validation: false)
        expect(new_user).not_to be_valid
        expect(new_user.errors[:last_ip_addr]).to be_present
      end

      it "is valid when sock puppet validation is disabled" do
        user = build(:user)
        expect(user).to be_valid
      end
    end
  end
end
