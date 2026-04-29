# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostQueryBuilder do
  include_context "as admin"

  def run(query)
    PostQueryBuilder.new(query).search
  end

  describe "parent: metatag" do
    describe "parent:none" do
      it "includes posts with no parent" do
        post = create(:post)
        post.update_columns(parent_id: nil)
        expect(run("parent:none")).to include(post)
      end

      it "excludes child posts" do
        parent = create(:post)
        child = create(:post)
        child.update_columns(parent_id: parent.id)
        expect(run("parent:none")).not_to include(child)
      end
    end

    describe "parent:any" do
      it "includes posts that have a parent" do
        parent = create(:post)
        child = create(:post)
        child.update_columns(parent_id: parent.id)
        expect(run("parent:any")).to include(child)
      end

      it "excludes posts with no parent" do
        post = create(:post)
        post.update_columns(parent_id: nil)
        expect(run("parent:any")).not_to include(post)
      end
    end

    describe "parent:ID" do
      it "includes posts whose parent_id equals the given ID" do
        parent = create(:post)
        child = create(:post)
        child.update_columns(parent_id: parent.id)
        expect(run("parent:#{parent.id}")).to include(child)
      end

      it "excludes posts with a different parent_id" do
        parent_a = create(:post)
        parent_b = create(:post)
        child_b = create(:post)
        child_b.update_columns(parent_id: parent_b.id)
        expect(run("parent:#{parent_a.id}")).not_to include(child_b)
      end

      it "excludes posts with no parent" do
        parent = create(:post)
        unrelated = create(:post)
        unrelated.update_columns(parent_id: nil)
        expect(run("parent:#{parent.id}")).not_to include(unrelated)
      end
    end

    describe "-parent:ID" do
      it "excludes posts whose parent_id equals the given ID" do
        parent = create(:post)
        child = create(:post)
        child.update_columns(parent_id: parent.id)
        expect(run("-parent:#{parent.id}")).not_to include(child)
      end

      it "includes posts with a different parent_id" do
        parent_a = create(:post)
        parent_b = create(:post)
        child_b = create(:post)
        child_b.update_columns(parent_id: parent_b.id)
        expect(run("-parent:#{parent_a.id}")).to include(child_b)
      end
    end
  end

  describe "child: metatag" do
    describe "child:none" do
      it "includes posts with no children" do
        post = create(:post)
        post.update_columns(has_children: false)
        expect(run("child:none")).to include(post)
      end

      it "excludes posts that have children" do
        post = create(:post)
        post.update_columns(has_children: true)
        expect(run("child:none")).not_to include(post)
      end
    end

    describe "child:any" do
      it "includes posts that have children" do
        post = create(:post)
        post.update_columns(has_children: true)
        expect(run("child:any")).to include(post)
      end

      it "excludes posts with no children" do
        post = create(:post)
        post.update_columns(has_children: false)
        expect(run("child:any")).not_to include(post)
      end
    end
  end
end
