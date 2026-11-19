# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::Tags, :populate_exports do
  include_context "as admin"

  let(:dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(dir) }

  it "imports tags, aliases and implications with their production ids and stub users" do
    dragon = create(:tag, name: "dragon", category: 5, post_count: 12)
    wyvern = create(:tag, name: "wyvern", category: 5)
    create(:tag, name: "scalie", category: 0)
    aliased = create(:active_tag_alias, antecedent_name: "drake", consequent_name: "dragon")
    implied = create(:active_tag_implication, antecedent_name: "wyvern", consequent_name: "dragon")
    aliased.update_columns(creator_id: 777_777, approver_id: 777_778)
    implied.update_columns(descendant_names: %w[dragon scalie])
    tag_count = Tag.count # the alias and implication create their missing tags
    %w[tags tag_aliases tag_implications].each { |name| write_export(name, dir) }
    TagImplication.delete_all
    TagAlias.delete_all
    Tag.delete_all

    result = nil
    expect { result = described_class.new(dir: dir).call }.to output(/tags: #{tag_count} inserted/).to_stdout

    expect(result).to eq(tags: tag_count, aliases: 1, implications: 1)
    expect(Tag.count).to eq(tag_count)
    expect(Tag.find(dragon.id)).to have_attributes(name: "dragon", category: 5, post_count: 12)
    expect(Tag.find(wyvern.id).name).to eq("wyvern")
    expect(TagAlias.find(aliased.id)).to have_attributes(antecedent_name: "drake", status: "active", creator_id: 777_777, forum_topic_id: nil)
    expect(TagImplication.find(implied.id).descendant_names).to eq(%w[dragon scalie])
    expect(User.find(777_777).name).to eq("user_777777")
    expect(User.find(777_778).name).to eq("user_777778")
    expect(Tag.create!(name: "newtag").id).to be > dragon.id

    expect { expect(described_class.new(dir: dir).call).to eq(tags: 0, aliases: 0, implications: 0) }.to output.to_stdout
  end

  it "refuses fix_counts until posts can be imported" do
    expect { described_class.new(fix_counts: true).call }.to raise_error(ArgumentError, /step 3/)
  end
end
