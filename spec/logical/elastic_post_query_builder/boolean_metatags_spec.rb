# frozen_string_literal: true

require "rails_helper"

RSpec.describe ElasticPostQueryBuilder do
  include_context "as member"

  def build_query(query_string, **opts)
    ElasticPostQueryBuilder.new(query_string, resolve_aliases: false, enable_safe_mode: false, **opts)
  end

  describe "boolean metatags" do
    describe "hassource" do
      it "adds an exists clause to must for hassource:true" do
        expect(build_query("hassource:true").must).to include({ exists: { field: :source } })
      end

      it "adds an exists clause to must_not for hassource:false" do
        expect(build_query("hassource:false").must_not).to include({ exists: { field: :source } })
      end
    end

    describe "hasdescription" do
      it "adds an exists clause to must for hasdescription:true" do
        expect(build_query("hasdescription:true").must).to include({ exists: { field: :description } })
      end

      it "adds an exists clause to must_not for hasdescription:false" do
        expect(build_query("hasdescription:false").must_not).to include({ exists: { field: :description } })
      end
    end

    describe "ischild" do
      it "adds an exists clause on parent to must for ischild:true" do
        expect(build_query("ischild:true").must).to include({ exists: { field: :parent } })
      end

      it "adds an exists clause on parent to must_not for ischild:false" do
        expect(build_query("ischild:false").must_not).to include({ exists: { field: :parent } })
      end
    end

    describe "isparent" do
      it "adds a has_children:true term to must for isparent:true" do
        expect(build_query("isparent:true").must).to include({ term: { has_children: true } })
      end

      it "adds a has_children:false term to must for isparent:false" do
        expect(build_query("isparent:false").must).to include({ term: { has_children: false } })
      end
    end

    describe "inpool" do
      it "adds an exists clause on pools to must for inpool:true" do
        expect(build_query("inpool:true").must).to include({ exists: { field: :pools } })
      end

      it "adds an exists clause on pools to must_not for inpool:false" do
        expect(build_query("inpool:false").must_not).to include({ exists: { field: :pools } })
      end
    end

    describe "pending_replacements" do
      it "adds a has_pending_replacements:true term for pending_replacements:true" do
        expect(build_query("pending_replacements:true").must).to include({ term: { has_pending_replacements: true } })
      end

      it "adds a has_pending_replacements:false term for pending_replacements:false" do
        expect(build_query("pending_replacements:false").must).to include({ term: { has_pending_replacements: false } })
      end
    end

    describe "artverified" do
      it "adds an artverified:true term for artverified:true" do
        expect(build_query("artverified:true").must).to include({ term: { artverified: true } })
      end

      it "adds an artverified:false term for artverified:false" do
        expect(build_query("artverified:false").must).to include({ term: { artverified: false } })
      end
    end

    describe "child metatag" do
      it "adds has_children:false to must for child:none" do
        expect(build_query("child:none").must).to include({ term: { has_children: false } })
      end

      it "adds has_children:true to must for child:any" do
        expect(build_query("child:any").must).to include({ term: { has_children: true } })
      end
    end

    describe "BOOLEAN_METATAG aliases" do
      it "hasparent is an alias for ischild (adds exists on parent)" do
        expect(build_query("hasparent:true").must).to include({ exists: { field: :parent } })
      end

      it "haschildren is an alias for isparent (adds has_children term)" do
        expect(build_query("haschildren:true").must).to include({ term: { has_children: true } })
      end
    end
  end
end
