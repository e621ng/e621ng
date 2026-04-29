# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostVersionQueryBuilder do
  include_context "as member"

  def make_builder(query = {})
    ElasticPostVersionQueryBuilder.new(query)
  end

  # ---------------------------------------------------------------------------
  # id
  # ---------------------------------------------------------------------------

  describe "#build — id" do
    it "adds no clause when id is blank" do
      builder = make_builder(id: nil)
      expect(builder.must).to be_empty
    end

    it "adds a term clause for an exact id" do
      builder = make_builder(id: "5")
      expect(builder.must).to include({ term: { id: 5 } })
    end
  end

  # ---------------------------------------------------------------------------
  # updater_name
  # ---------------------------------------------------------------------------

  describe "#build — updater_name" do
    it "adds no clause when updater_name is blank" do
      builder = make_builder(updater_name: nil)
      expect(builder.must).to be_empty
    end

    it "adds a term clause on updater_id when the user is found" do
      allow(User).to receive(:name_to_id).with("alice").and_return(42)
      builder = make_builder(updater_name: "alice")
      expect(builder.must).to include({ term: { updater_id: 42 } })
    end

    it "adds no clause when the user is not found" do
      allow(User).to receive(:name_to_id).with("nobody").and_return(nil)
      builder = make_builder(updater_name: "nobody")
      expect(builder.must).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # updater_id / post_id / parent_id (delegated range relations)
  # ---------------------------------------------------------------------------

  describe "#build — updater_id" do
    it "adds a term clause for an exact updater_id" do
      builder = make_builder(updater_id: "7")
      expect(builder.must).to include({ term: { updater_id: 7 } })
    end
  end

  describe "#build — post_id" do
    it "adds a term clause for an exact post_id" do
      builder = make_builder(post_id: "3")
      expect(builder.must).to include({ term: { post_id: 3 } })
    end
  end

  describe "#build — parent_id" do
    it "adds a term clause for an exact parent_id" do
      builder = make_builder(parent_id: "10")
      expect(builder.must).to include({ term: { parent_id: 10 } })
    end
  end

  # ---------------------------------------------------------------------------
  # rating
  # ---------------------------------------------------------------------------

  describe "#build — rating" do
    it "adds no clause when rating is blank" do
      builder = make_builder(rating: nil)
      expect(builder.must).to be_empty
    end

    it "takes the first character of the rating value, lowercased" do
      builder = make_builder(rating: "safe")
      expect(builder.must).to include({ term: { rating: "s" } })
    end

    it "downcases the rating value before taking the first character" do
      builder = make_builder(rating: "Explicit")
      expect(builder.must).to include({ term: { rating: "e" } })
    end

    it "adds one term clause per comma-separated rating" do
      builder = make_builder(rating: "safe,explicit")
      expect(builder.must).to include({ term: { rating: "s" } })
      expect(builder.must).to include({ term: { rating: "e" } })
    end
  end

  # ---------------------------------------------------------------------------
  # rating_changed
  # ---------------------------------------------------------------------------

  describe "#build — rating_changed" do
    it "adds no clause when rating_changed is blank" do
      builder = make_builder(rating_changed: nil)
      expect(builder.must).to be_empty
    end

    it "adds only rating_changed:true when value is 'any'" do
      builder = make_builder(rating_changed: "any")
      expect(builder.must).to include({ term: { rating_changed: true } })
      expect(builder.must).not_to include(include(term: include(:rating)))
    end

    it "adds both a rating term and rating_changed:true for a specific value" do
      builder = make_builder(rating_changed: "s")
      expect(builder.must).to include({ term: { rating: "s" } })
      expect(builder.must).to include({ term: { rating_changed: true } })
    end
  end

  # ---------------------------------------------------------------------------
  # parent_id_changed
  # ---------------------------------------------------------------------------

  describe "#build — parent_id_changed" do
    it "adds no clause when parent_id_changed is blank" do
      builder = make_builder(parent_id_changed: nil)
      expect(builder.must).to be_empty
    end

    it "adds a parent_id term and parent_id_changed:true when value is an Integer" do
      builder = make_builder(parent_id_changed: 42)
      expect(builder.must).to include({ term: { parent_id: 42 } })
      expect(builder.must).to include({ term: { parent_id_changed: true } })
    end

    it "adds an exists clause and parent_id_changed:true when value is a non-Integer string" do
      builder = make_builder(parent_id_changed: "any")
      expect(builder.must).to include({ exists: { field: :parent_id } })
      expect(builder.must).to include({ term: { parent_id_changed: true } })
    end
  end

  # ---------------------------------------------------------------------------
  # tag fields
  # ---------------------------------------------------------------------------

  describe "#build — tag fields" do
    %i[tags tags_removed tags_added locked_tags locked_tags_removed locked_tags_added].each do |field|
      describe field.to_s do
        it "adds no clause when #{field} is nil" do
          builder = make_builder(field => nil)
          expect(builder.must).to be_empty
        end

        it "adds a term clause for a single tag in #{field}" do
          builder = make_builder(field => "canine")
          expect(builder.must).to include({ term: { field => "canine" } })
        end

        it "adds one term clause per space-separated tag in #{field}" do
          builder = make_builder(field => "canine feline")
          expect(builder.must).to include({ term: { field => "canine" } })
          expect(builder.must).to include({ term: { field => "feline" } })
        end

        it "downcases tag values in #{field} before scanning" do
          builder = make_builder(field => "Canine")
          expect(builder.must).to include({ term: { field => "canine" } })
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # updated_at
  # ---------------------------------------------------------------------------

  describe "#build — updated_at" do
    it "adds no clause when updated_at is blank" do
      builder = make_builder(updated_at: nil)
      expect(builder.must).to be_empty
    end

    it "adds a clause when updated_at is a date range string" do
      builder = make_builder(updated_at: ">2024-01-01")
      expect(builder.must).not_to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # reason
  # ---------------------------------------------------------------------------

  describe "#build — reason" do
    it "adds no clause when reason is blank" do
      builder = make_builder(reason: nil)
      expect(builder.must).to be_empty
    end

    it "adds a match clause for a non-blank reason" do
      builder = make_builder(reason: "mass update")
      expect(builder.must).to include({ match: { reason: "mass update" } })
    end
  end

  # ---------------------------------------------------------------------------
  # description
  # ---------------------------------------------------------------------------

  describe "#build — description" do
    it "adds no clause when description is blank" do
      builder = make_builder(description: nil)
      expect(builder.must).to be_empty
    end

    it "adds a match clause for a non-blank description" do
      builder = make_builder(description: "character info")
      expect(builder.must).to include({ match: { description: "character info" } })
    end
  end

  # ---------------------------------------------------------------------------
  # description_changed
  # ---------------------------------------------------------------------------

  describe "#build — description_changed" do
    it "adds no clause when description_changed is blank" do
      builder = make_builder(description_changed: nil)
      expect(builder.must).to be_empty
    end

    it "adds term true for a truthy value" do
      builder = make_builder(description_changed: "true")
      expect(builder.must).to include({ term: { description_changed: true } })
    end

    it "adds term false for a falsy value" do
      builder = make_builder(description_changed: "false")
      expect(builder.must).to include({ term: { description_changed: false } })
    end
  end

  # ---------------------------------------------------------------------------
  # source_changed
  # ---------------------------------------------------------------------------

  describe "#build — source_changed" do
    it "adds no clause when source_changed is blank" do
      builder = make_builder(source_changed: nil)
      expect(builder.must).to be_empty
    end

    it "adds term true for a truthy value" do
      builder = make_builder(source_changed: "true")
      expect(builder.must).to include({ term: { source_changed: true } })
    end

    it "adds term false for a falsy value" do
      builder = make_builder(source_changed: "false")
      expect(builder.must).to include({ term: { source_changed: false } })
    end
  end

  # ---------------------------------------------------------------------------
  # uploads
  # ---------------------------------------------------------------------------

  describe "#build — uploads" do
    it "adds no clause when uploads is blank" do
      builder = make_builder(uploads: nil)
      expect(builder.must).to be_empty
      expect(builder.must_not).to be_empty
    end

    it "adds version:1 to must for 'only'" do
      builder = make_builder(uploads: "only")
      expect(builder.must).to include({ term: { version: 1 } })
    end

    it "adds version:1 to must_not for 'excluded'" do
      builder = make_builder(uploads: "excluded")
      expect(builder.must_not).to include({ term: { version: 1 } })
    end

    it "is case-insensitive for 'only'" do
      builder = make_builder(uploads: "Only")
      expect(builder.must).to include({ term: { version: 1 } })
    end

    it "is case-insensitive for 'excluded'" do
      builder = make_builder(uploads: "Excluded")
      expect(builder.must_not).to include({ term: { version: 1 } })
    end

    it "adds no clause for an unrecognized value" do
      builder = make_builder(uploads: "all")
      expect(builder.must).to be_empty
      expect(builder.must_not).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # order
  # ---------------------------------------------------------------------------

  describe "#build — order" do
    it "defaults to id descending when no order is given" do
      builder = make_builder
      expect(builder.order).to include({ id: { order: "desc" } })
    end

    it "sorts id ascending for 'id_asc'" do
      builder = make_builder(order: "id_asc")
      expect(builder.order).to include({ id: { order: "asc" } })
    end

    it "sorts id descending for 'id_desc'" do
      builder = make_builder(order: "id_desc")
      expect(builder.order).to include({ id: { order: "desc" } })
    end
  end
end
