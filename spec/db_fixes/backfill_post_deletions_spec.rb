# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/fixes/146_backfill_post_deletions")

RSpec.describe Fixes::BackfillPostDeletions do
  include_context "as admin"

  def run!
    expect { described_class.run }.to output.to_stdout
  end

  def deletion_for(flag)
    PostDeletion.find_by!(source_post_flag_id: flag.id)
  end

  def legacy_appeal(flag_id)
    create(:appeal).tap { |a| a.update_columns(qtype: "flag", disp_id: flag_id) }
  end

  it "copies a deletion flag of a deleted post as the active deletion" do
    flag = create(:legacy_deletion_post_flag, reason: "spam", created_at: Time.zone.parse("2026-01-02 03:04:05"))
    run!

    expect(deletion_for(flag)).to have_attributes(
      post_id: flag.post_id,
      deleter_id: flag.creator_id,
      reason: "spam",
      is_undeleted: false,
      created_at: Time.zone.parse("2026-01-02 03:04:05"),
    )
    expect(flag.post.current_deletion).to eq(deletion_for(flag))
  end

  it "keeps only the newest unresolved flag of a post active" do
    post = create(:deleted_post)
    older = create(:legacy_deletion_post_flag, post: post)
    newer = create(:legacy_deletion_post_flag, post: post)
    run!

    expect(deletion_for(older).is_undeleted).to be(true)
    expect(deletion_for(newer).is_undeleted).to be(false)
  end

  it "copies flags of undeleted posts as undeleted and stamps the undeleter" do
    post = create(:post)
    flag = create(:legacy_deletion_post_flag, post: post, is_resolved: true, created_at: 2.days.ago)
    undeleter = create(:janitor_user)
    PostEvent.add(post.id, undeleter, :undeleted)
    run!

    expect(deletion_for(flag)).to have_attributes(is_undeleted: true, undeleter_id: undeleter.id)
    expect(deletion_for(flag).undeleted_at).to be_present
  end

  it "replaces a blank reason" do
    flag = create(:legacy_deletion_post_flag, reason: " ")
    run!

    expect(deletion_for(flag).reason).to eq("Unknown")
  end

  it "re-anchors appeals to the copied deletion" do
    flag = create(:legacy_deletion_post_flag)
    appeal = legacy_appeal(flag.id)
    run!

    expect(appeal.reload).to have_attributes(qtype: "post_deletion", disp_id: deletion_for(flag).id)
  end

  it "negates the id of appeals whose flag no longer exists" do
    appeal = legacy_appeal(987_654)
    run!

    expect(appeal.reload).to have_attributes(qtype: "post_deletion", disp_id: -987_654)
  end

  it "changes nothing when run again" do
    create(:legacy_deletion_post_flag)
    legacy_appeal(create(:legacy_deletion_post_flag).id)
    run!

    expect { run! }.not_to(change { PostDeletion.order(:id).map(&:attributes) })
    expect { described_class.run }.to output(/Copied deletion flags: 0\n.*Marked undeleted: 0\n.*Remapped appeals: 0/m).to_stdout
  end

  it "copies a late flag as undeleted when the post already has an active deletion" do
    post = create(:post)
    post.delete!("new code")
    flag = create(:legacy_deletion_post_flag, post: post)
    run!

    expect(deletion_for(flag).is_undeleted).to be(true)
    expect(post.current_deletion.reason).to eq("new code")
  end

  it "marks a copied deletion undeleted once the old code undeletes the post" do
    flag = create(:legacy_deletion_post_flag)
    run!

    PostFlag.unscoped.where(id: flag.id).update_all(is_resolved: true)
    flag.post.update_columns(is_deleted: false)
    run!

    expect(deletion_for(flag).is_undeleted).to be(true)
  end
end
