# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          TagNameValidator                                   #
# --------------------------------------------------------------------------- #
#
# Tests every rule enforced by TagNameValidator#validate_each.
# The validator is used by Tag on :name, on: :create.
#
# Tests run against a real Tag record via FactoryBot. An admin CurrentUser is
# set globally so that user_can_create_tag? doesn't interfere with these tests.

RSpec.describe TagNameValidator, type: :model do
  include_context "as admin"

  describe "blank / all underscores" do
    it "is invalid when the name is all underscores" do
      tag = build(:tag, name: "___")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to be_present
    end
  end

  describe "starts with dash" do
    it "is invalid when the name starts with '-'" do
      tag = build(:tag, name: "-bad_tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("cannot begin with a dash"))
    end
  end

  describe "starts with tilde" do
    it "is invalid when the name starts with '~'" do
      tag = build(:tag, name: "~bad_tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("cannot begin with a tilde"))
    end
  end

  describe "starts with underscore" do
    it "is invalid when the name starts with '_'" do
      tag = build(:tag, name: "_bad_tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("cannot begin with an underscore"))
    end
  end

  describe "ends with underscore" do
    it "is invalid when the name ends with '_'" do
      tag = build(:tag, name: "bad_tag_")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("cannot end with an underscore"))
    end
  end

  describe "consecutive underscores, hyphens, or tildes" do
    it "is invalid with consecutive underscores" do
      tag = build(:tag, name: "bad__tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("consecutive"))
    end

    it "is invalid with consecutive hyphens" do
      tag = build(:tag, name: "bad--tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("consecutive"))
    end

    it "is invalid with consecutive tildes" do
      tag = build(:tag, name: "bad~~tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("consecutive"))
    end
  end

  describe "asterisk" do
    it "is invalid when the name contains '*'" do
      tag = build(:tag, name: "bad*tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("asterisks"))
    end
  end

  describe "comma" do
    it "is invalid when the name contains ','" do
      tag = build(:tag, name: "bad,tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("commas"))
    end
  end

  describe "octothorpe" do
    it "is invalid when the name contains '#'" do
      tag = build(:tag, name: "bad#tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("octothorpes"))
    end
  end

  describe "percent sign" do
    it "is invalid when the name contains '%'" do
      tag = build(:tag, name: "bad%tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("percent signs"))
    end
  end

  describe "non-printable character" do
    it "is invalid when the name contains a non-printable character" do
      tag = build(:tag, name: "bad\x01tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("non-printable"))
    end
  end

  describe "forbidden leading characters" do
    %w[+ ( ) { } [ ] /].each do |char|
      it "is invalid when the name starts with '#{char}'" do
        tag = build(:tag, name: "#{char}bad_tag")
        expect(tag).not_to be_valid
        expect(tag.errors[:name]).to be_present
      end
    end

    it "is invalid when the name starts with a backtick" do
      tag = build(:tag, name: "`bad_tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to be_present
    end
  end

  describe "metatag prefix" do
    it "is invalid when the name starts with a metatag prefix" do
      tag = build(:tag, name: "order:score")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("cannot begin with"))
    end
  end

  describe "category prefix" do
    it "is invalid when the name starts with a category prefix" do
      tag = build(:tag, name: "director:some_director")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("cannot begin with"))
    end
  end

  describe "invisible Unicode characters" do
    it "is invalid when the name contains a non-breaking space (\\u00A0)" do
      tag = build(:tag, name: "bad\u00A0tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("invisible"))
    end

    it "is invalid when the name contains a zero-width space (\\u200B)" do
      tag = build(:tag, name: "bad\u200Btag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("invisible"))
    end
  end

  describe "secondary validations" do
    it "is invalid when the name contains a peso sign ('$')" do
      tag = build(:tag, name: "bad$tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("peso signs"))
    end

    it "is invalid when the name contains a backslash" do
      tag = build(:tag, name: 'bad\\tag')
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("back slashes"))
    end

    it "is invalid when the name starts with a colon" do
      tag = build(:tag, name: ":bad_tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("colon"))
    end
  end

  describe "non-ASCII characters" do
    it "is invalid when the name contains non-ASCII characters" do
      tag = build(:tag, name: "tëst_tag")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include(include("ASCII"))
    end
  end

  describe "valid name" do
    it "passes all rules for a typical well-formed tag name" do
      tag = build(:tag, name: "valid_tag-name")
      expect(tag).to be_valid
    end

    it "passes for a name with numbers" do
      tag = build(:tag, name: "tag_2024")
      expect(tag).to be_valid
    end

    it "passes for a single character name" do
      tag = build(:tag, name: "a")
      expect(tag).to be_valid
    end
  end
end
