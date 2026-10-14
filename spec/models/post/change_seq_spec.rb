# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "ChangeSeqMethods" do
    describe ".change_seq_untracked_columns" do
      it "is empty" do
        # A column showing up here means it was added to the posts table without anyone
        # deciding whether it should bump change_seq - see Post::CHANGE_SEQ_IGNORED.
        expect(Post.change_seq_untracked_columns).to be_empty
      end
    end

    describe "CHANGE_SEQ_IGNORED" do
      it "does not overlap with the trigger's tracked columns" do
        # A column in both places means the trigger and CHANGE_SEQ_IGNORED disagree about
        # whether it should bump change_seq.
        expect(Post.change_seq_tracked_columns & Post::CHANGE_SEQ_IGNORED).to be_empty
      end
    end

    describe "the posts_trigger_change_seq() database trigger" do
      subject(:post) { create(:post) }

      # update_column issues a plain SQL UPDATE without running validations or callbacks,
      # so these specs exercise the trigger itself rather than the model's business logic
      # around each column.
      def distinct_value_for(column)
        col = Post.columns_hash[column.to_s]
        current = post.read_attribute(column)

        return(current == "s" ? "e" : "s") if column == :rating
        return Array(current) + [rand(1..1_000_000)] if col.array?

        case col.type
        when :boolean  then !current
        when :integer  then current.to_i + 1
        when :datetime then 1.minute.from_now.change(usec: 0)
        when :jsonb    then { "changed" => SecureRandom.hex(4) }
        else "#{current}_#{SecureRandom.hex(4)}"
        end
      end

      it "found the trigger function" do
        expect(Post.change_seq_tracked_columns).not_to be_empty
      end

      Post.change_seq_tracked_columns.sort.each do |column|
        it "bumps change_seq when #{column} changes" do
          old_value = post.read_attribute(column)
          old_seq = post.change_seq

          post.update_column(column, distinct_value_for(column))
          post.reload

          expect(post.read_attribute(column)).not_to eq(old_value)
          expect(post.change_seq).not_to eq(old_seq)
        end
      end

      it "does not bump change_seq when only an ignored column changes" do
        old_seq = post.change_seq

        post.update_column(:fav_count, post.fav_count + 1)
        post.reload

        expect(post.change_seq).to eq(old_seq)
      end
    end
  end
end
