# frozen_string_literal: true

require "rails_helper"

# Tests status/flag metatags: status:, -status:, locked:, and boolean metatags
# (hassource:, hasdescription:, isparent:, ischild:, and their aliases).

RSpec.describe TagQuery, type: :model do
  include_context "as member"

  describe "status: metatag" do
    it "stores the status value in q[:status]" do
      expect(TagQuery.new("status:pending")[:status]).to eq("pending")
    end

    it "normalises the value to lowercase" do
      expect(TagQuery.new("status:Pending")[:status]).to eq("pending")
    end

    it "clears status_must_not when status is set" do
      tq = TagQuery.new("-status:deleted status:active")
      expect(tq[:status_must_not]).to be_nil
      expect(tq[:status]).to eq("active")
    end

    it "sets show_deleted to true for status:deleted" do
      expect(TagQuery.new("status:deleted")[:show_deleted]).to be(true)
    end

    it "sets show_deleted to true for status:all" do
      expect(TagQuery.new("status:all")[:show_deleted]).to be(true)
    end

    it "does not set show_deleted for status:pending" do
      expect(TagQuery.new("status:pending")[:show_deleted]).to be(false)
    end
  end

  describe "-status: metatag" do
    it "stores the value in q[:status_must_not]" do
      expect(TagQuery.new("-status:deleted")[:status_must_not]).to eq("deleted")
    end

    it "clears q[:status] when -status is set" do
      tq = TagQuery.new("status:pending -status:deleted")
      expect(tq[:status]).to be_nil
      expect(tq[:status_must_not]).to eq("deleted")
    end

    it "sets show_deleted to true for -status:deleted" do
      expect(TagQuery.new("-status:deleted")[:show_deleted]).to be(true)
    end
  end

  describe "locked: metatag" do
    it "locked:rating stores :rating in q[:locked]" do
      tq = TagQuery.new("locked:rating")
      expect(tq[:locked]).to include(:rating)
    end

    it "locked:note stores :note in q[:locked]" do
      tq = TagQuery.new("locked:note")
      expect(tq[:locked]).to include(:note)
    end

    it "locked:notes is an alias for locked:note" do
      tq = TagQuery.new("locked:notes")
      expect(tq[:locked]).to include(:note)
    end

    it "locked:status stores :status in q[:locked]" do
      tq = TagQuery.new("locked:status")
      expect(tq[:locked]).to include(:status)
    end

    it "-locked:rating stores :rating in q[:locked_must_not]" do
      tq = TagQuery.new("-locked:rating")
      expect(tq[:locked_must_not]).to include(:rating)
    end

    it "~locked:rating stores :rating in q[:locked_should]" do
      tq = TagQuery.new("~locked:rating")
      expect(tq[:locked_should]).to include(:rating)
    end
  end

  describe "ratinglocked: metatag" do
    it "ratinglocked:true adds :rating to q[:locked]" do
      tq = TagQuery.new("ratinglocked:true")
      expect(tq[:locked]).to include(:rating)
    end

    it "ratinglocked:false adds :rating to q[:locked_must_not]" do
      tq = TagQuery.new("ratinglocked:false")
      expect(tq[:locked_must_not]).to include(:rating)
    end
  end

  describe "notelocked: metatag" do
    it "notelocked:true adds :note to q[:locked]" do
      tq = TagQuery.new("notelocked:true")
      expect(tq[:locked]).to include(:note)
    end

    it "notelocked:false adds :note to q[:locked_must_not]" do
      tq = TagQuery.new("notelocked:false")
      expect(tq[:locked_must_not]).to include(:note)
    end
  end

  describe "statuslocked: metatag" do
    it "statuslocked:true adds :status to q[:locked]" do
      tq = TagQuery.new("statuslocked:true")
      expect(tq[:locked]).to include(:status)
    end

    it "statuslocked:false adds :status to q[:locked_must_not]" do
      tq = TagQuery.new("statuslocked:false")
      expect(tq[:locked_must_not]).to include(:status)
    end
  end

  describe "boolean metatags" do
    shared_examples "a boolean metatag" do |input:, expected_key:, true_value:, false_value:|
      it "#{input}:true sets #{expected_key} to true" do
        expect(TagQuery.new("#{input}:true")[expected_key]).to be(true_value)
      end

      it "#{input}:false sets #{expected_key} to false" do
        expect(TagQuery.new("#{input}:false")[expected_key]).to be(false_value)
      end

      it "is case-insensitive (TRUE works)" do
        expect(TagQuery.new("#{input}:TRUE")[expected_key]).to be(true_value)
      end
    end

    describe "hassource:" do
      include_examples "a boolean metatag",
                       input: "hassource", expected_key: :hassource,
                       true_value: true, false_value: false
    end

    describe "hasdescription:" do
      include_examples "a boolean metatag",
                       input: "hasdescription", expected_key: :hasdescription,
                       true_value: true, false_value: false
    end

    describe "isparent:" do
      include_examples "a boolean metatag",
                       input: "isparent", expected_key: :isparent,
                       true_value: true, false_value: false
    end

    describe "ischild:" do
      include_examples "a boolean metatag",
                       input: "ischild", expected_key: :ischild,
                       true_value: true, false_value: false
    end

    describe "inpool:" do
      include_examples "a boolean metatag",
                       input: "inpool", expected_key: :inpool,
                       true_value: true, false_value: false
    end

    describe "artverified:" do
      include_examples "a boolean metatag",
                       input: "artverified", expected_key: :artverified,
                       true_value: true, false_value: false
    end

    describe "pending_replacements:" do
      include_examples "a boolean metatag",
                       input: "pending_replacements", expected_key: :pending_replacements,
                       true_value: true, false_value: false
    end
  end

  describe "boolean metatag aliases" do
    it "hasparent:true maps to q[:ischild] = true" do
      expect(TagQuery.new("hasparent:true")[:ischild]).to be(true)
    end

    it "hasparent:false maps to q[:ischild] = false" do
      expect(TagQuery.new("hasparent:false")[:ischild]).to be(false)
    end

    it "haschild:true maps to q[:isparent] = true" do
      expect(TagQuery.new("haschild:true")[:isparent]).to be(true)
    end

    it "haschildren:true maps to q[:isparent] = true" do
      expect(TagQuery.new("haschildren:true")[:isparent]).to be(true)
    end
  end
end
