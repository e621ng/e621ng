# e621ng RSpec Patterns & Conventions

This document is a reference for writing new tests. Read this **instead of** re-exploring existing specs.

---

## Directory Structure

```
spec/
├── factories/                    # FactoryBot definitions, one file per model
├── models/                       # Model specs, one subdirectory per model
│   └── {model}/
│       ├── factory_spec.rb       # Factory sanity checks
│       ├── validations_spec.rb
│       ├── normalizations_spec.rb
│       ├── instance_methods_spec.rb
│       ├── permissions_spec.rb   # Authorization / visibility
│       ├── scopes_spec.rb        # Scopes and class methods
│       ├── search_spec.rb        # .search / query methods
│       ├── log_methods_spec.rb   # ModAction audit logging
│       └── {domain}_methods_spec.rb  # e.g. count_methods, name_methods
├── middleware/
├── logical/
├── support/
│   ├── shared_examples/
│   │   └── tag_relationship_examples.rb
│   ├── current_user_contexts.rb  # "as admin", "as member", etc.
│   └── tag_categories.rb         # let(:general_tag_category) etc.
├── fixtures/
├── rails_helper.rb
└── spec_helper.rb
```

---

## rails_helper.rb Highlights

- `config.include FactoryBot::Syntax::Methods` — use `create`, `build`, `build_stubbed` without prefix
- `config.include ActiveSupport::Testing::TimeHelpers` — use [`freeze_time`](https://api.rubyonrails.org/v5.2.4/classes/ActiveSupport/Testing/TimeHelpers.html#method-i-freeze_time), [`travel`](https://api.rubyonrails.org/v5.2.4/classes/ActiveSupport/Testing/TimeHelpers.html#method-i-travel), [`travel_to`](https://api.rubyonrails.org/v5.2.4/classes/ActiveSupport/Testing/TimeHelpers.html#method-i-travel_to) without prefix
- `config.use_transactional_fixtures = true` — every test rolls back automatically
- `before(:suite)` seeds: `admin` user, system user (`Danbooru.config.system_user`), `ForumCategory` "Tag Alias and Implication Suggestions"
- All files in `spec/support/**/*.rb` are auto-required

---

## Shared Contexts

### Current user

```ruby
include_context "as admin"
include_context "as moderator"
include_context "as janitor"
include_context "as privileged"
include_context "as member"
```

Each context creates a user of that level and sets `CurrentUser.user` / `CurrentUser.ip_addr = "127.0.0.1"` in `before(:each)`, and clears both in `after(:each)`.

Factory mapping: `admin` → `:admin_user`, `moderator` → `:moderator_user`, `janitor` → `:janitor_user`, `privileged` → `:privileged_user`, `member` → `:user`.

### Tag categories

```ruby
include_context "with tag categories"
```

Provides lazy `let` helpers:

```ruby
let(:general_tag_category)   { 0 }
let(:artist_tag_category)    { 1 }
let(:copyright_tag_category) { 3 }
let(:character_tag_category) { 4 }
let(:species_tag_category)   { 5 }
let(:invalid_tag_category)   { 6 }
let(:meta_tag_category)      { 7 }
let(:lore_tag_category)      { 8 }
```

---

## Factory Patterns

### Basic factory

```ruby
FactoryBot.define do
  factory :blip do
    body { "A short blip body." }
  end
end
```

### Sequences

```ruby
# Global (top-level)
sequence(:tag_name) { |n| "tag_#{n}" }
factory :tag do
  name { generate(:tag_name) }
end

# Inline (scoped to factory)
factory :tag_alias do
  sequence(:antecedent_name) { |n| "antecedent_tag_#{n}" }
  sequence(:consequent_name) { |n| "consequent_tag_#{n}" }
end
```

### Aliases

```ruby
factory :user, aliases: [:member_user] do
  # create(:user) and create(:member_user) are equivalent
end
```

### Nested / child factories

```ruby
factory :tag do
  name     { generate(:tag_name) }
  category { 0 }

  factory :artist_tag    { category { 1 } }
  factory :copyright_tag { category { 3 } }
  factory :character_tag { category { 4 } }
  factory :species_tag   { category { 5 } }
  factory :invalid_tag   { category { 6 } }
  factory :meta_tag      { category { 7 } }
  factory :lore_tag      { category { 8 } }
  factory :locked_tag    { is_locked { true } }
  factory :high_post_count_tag { post_count { Danbooru.config.tag_type_change_cutoff + 50 } }
end
```

### Associations

```ruby
# Standard (build or create depending on context)
association :creator, factory: :user

# Shorthand when factory name matches attribute name
association :user

# Force persistence (e.g. when level predicates must return true)
banner { create(:moderator_user) }
creator { create(:moderator_user) }
```

### Transient attributes + after hooks

The `:user` factory disables sock-puppet validation by default via a transient:

```ruby
transient do
  disable_sock_puppet_validation { true }
end

after(:build) do |_user, evaluator|
  instance = RSpec.current_example.example_group_instance
  instance.allow(Danbooru.config.custom_configuration)
          .to instance.receive(:enable_sock_puppet_validation?)
          .and_return(!evaluator.disable_sock_puppet_validation)
end
```

Opt back in with `create(:user, disable_sock_puppet_validation: false)`.

### Available factories (summary)

| Factory | Key variants |
|---------|-------------|
| `:user` | `:member_user`, `:privileged_user`, `:janitor_user`, `:moderator_user`, `:admin_user`, `:banned_user` |
| `:tag` | `:artist_tag`, `:copyright_tag`, `:character_tag`, `:species_tag`, `:meta_tag`, `:lore_tag`, `:locked_tag`, `:high_post_count_tag` |
| `:tag_alias` | `:active_tag_alias`, `:deleted_tag_alias` |
| `:ban` | `:permaban` |
| `:user_feedback` | `:neutral_user_feedback`, `:negative_user_feedback`, `:deleted_user_feedback` |
| `:post_set` | — |
| `:blip` | — |

---

## Test File Patterns

### Top-level structure

```ruby
RSpec.describe ModelName, type: :model do
  include_context "as admin"          # sets CurrentUser
  include_context "with tag categories" # if needed

  # Local helper to reduce noise in examples
  def make_thing(overrides = {})
    create(:model_name, **overrides)
  end

  describe "feature" do
    it "does something" do
    end
  end
end
```

### `let` vs `let!`

- `let` — lazy, created on first reference. Use for actors/roles that may not be needed in every example.
- `let!` — eager, created before each example. Use when the record must exist in the DB before the test body runs (e.g. scope exclusion tests).

```ruby
let(:admin)  { create(:admin_user) }   # only created when referenced
let!(:older) { create(:tag) }          # always created — needed for ordering/exclusion assertions
```

### `before` / `after` for `CurrentUser`

When `include_context "as <role>"` is not enough (e.g. you need multiple users):

```ruby
let(:creator)   { create(:user) }
let(:moderator) { create(:moderator_user) }

before(:each) do
  CurrentUser.user    = creator
  CurrentUser.ip_addr = "127.0.0.1"
end

after(:each) do
  CurrentUser.user    = nil
  CurrentUser.ip_addr = nil
end
```

### `build` vs `create`

- `build` — does not persist. Use for **validation tests** (faster, no DB write).
- `create` — persists. Use whenever the test needs the record in the DB (callbacks, scopes, associations, audit logs).

---

## Patterns by Concern

### Validations

```ruby
describe "validations" do
  describe "name length" do
    it "is invalid with an empty name" do
      record = build(:tag, name: "")
      expect(record).not_to be_valid
      expect(record.errors[:name]).to be_present
    end

    it "is invalid when name exceeds 100 characters" do
      record = build(:tag, name: "a" * 101)
      expect(record).not_to be_valid
      expect(record.errors[:name]).to be_present
    end

    it "is valid at exactly 100 characters" do
      expect(build(:tag, name: "a" * 100)).to be_valid
    end
  end

  describe "name uniqueness" do
    it "is invalid when a tag with the same name already exists" do
      create(:tag, name: "duplicate")
      expect(build(:tag, name: "duplicate")).not_to be_valid
    end
  end

  describe "antecedent_and_consequent_are_different" do
    it "is invalid when antecedent equals consequent" do
      record = build(:tag_alias, antecedent_name: "same", consequent_name: "same")
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("Cannot alias or implicate a tag to itself")
    end
  end

  describe "referential integrity" do
    it "is invalid when creator_id references a non-existent user" do
      record = create(:tag_alias)
      record.creator_id = -1
      expect(record).not_to be_valid
      expect(record.errors[:creator]).to include("must exist")
    end
  end
end
```

### Normalizations

Test that callbacks or `before_validation` hooks transform attribute values:

```ruby
describe "body normalization" do
  it "converts \\r\\n line endings to \\n" do
    blip = create(:blip, body: "line one\r\nline two")
    expect(blip.body).to eq("line one\nline two")
  end

  it "applies normalization on update as well" do
    blip = create(:blip, body: "initial")
    blip.update!(body: "updated\r\nbody")
    expect(blip.body).to eq("updated\nbody")
  end
end
```

Call `record.valid?` to trigger `before_validation` without persisting:

```ruby
it "downcases antecedent_name" do
  record = build(:tag_alias, antecedent_name: "UPPER")
  record.valid?
  expect(record.antecedent_name).to eq("upper")
end
```

### Scopes

```ruby
describe "scopes" do
  describe ".active" do
    it "returns non-deleted records" do
      active  = create(:user_feedback, is_deleted: false)
      deleted = create(:user_feedback, is_deleted: true)
      expect(UserFeedback.active).to include(active)
      expect(UserFeedback.active).not_to include(deleted)
    end
  end

  describe ".visible" do
    let!(:active_record)  { create(:user_feedback, is_deleted: false) }
    let!(:deleted_record) { create(:user_feedback, is_deleted: true) }

    it "returns all records for staff" do
      expect(UserFeedback.visible(create(:janitor_user))).to include(active_record, deleted_record)
    end

    it "returns only active records for a regular member" do
      member = create(:user)
      expect(UserFeedback.visible(member)).to include(active_record)
      expect(UserFeedback.visible(member)).not_to include(deleted_record)
    end
  end

  describe ".default_order" do
    it "returns records newest-first" do
      older = create(:tag)
      newer = create(:tag)
      older.update_columns(created_at: 1.hour.ago)

      ids = Tag.default_order.ids
      expect(ids.index(newer.id)).to be < ids.index(older.id)
    end
  end
end
```

### Instance methods

```ruby
describe "#response?" do
  it "returns false when the blip has no parent" do
    expect(create(:blip).response?).to be false
  end

  it "returns true when the blip is a reply" do
    parent = create(:blip)
    expect(create(:blip, response_to: parent.id).response?).to be true
  end
end

describe "#delete!" do
  it "sets is_deleted to true" do
    blip = create(:blip)
    expect { blip.delete! }.to change { blip.reload.is_deleted }.from(false).to(true)
  end
end

# Stubbing a method on the instance
describe "#fix_post_count" do
  it "updates post_count to the value returned by real_post_count" do
    tag = create(:tag, post_count: 99)
    allow(tag).to receive(:real_post_count).and_return(42)
    tag.fix_post_count
    expect(tag.reload.post_count).to eq(42)
  end
end
```

### Permissions / authorization

```ruby
describe "#can_edit?" do
  it "allows an admin to edit any blip" do
    expect(blip.can_edit?(admin)).to be true
  end

  it "denies a non-creator non-admin" do
    expect(blip.can_edit?(other)).to be false
  end

  it "denies the creator more than 5 minutes after creation" do
    blip = create(:blip, created_at: 10.minutes.ago)
    expect(blip.can_edit?(creator)).to be false
  end
end

describe "#visible_to?" do
  it "is visible to anyone when not deleted" do
    expect(blip.visible_to?(other)).to be true
  end

  it "is not visible to an unrelated user when deleted" do
    blip.delete!
    expect(blip.visible_to?(other)).to be false
  end
end
```

### Search

```ruby
describe ".search" do
  describe "name_matches param" do
    it "filters by exact name" do
      expect(Tag.search(name_matches: "my_tag")).to include(my_tag)
    end

    it "supports trailing wildcard" do
      expect(Tag.search(name_matches: "prefix_*")).to include(tag_a, tag_b)
    end

    it "is case-insensitive" do
      expect(Tag.search(name_matches: "MY_TAG")).to include(my_tag)
    end
  end

  describe "category param" do
    it "accepts multiple comma-separated category IDs" do
      result = Tag.search(category: "0,1", hide_empty: false)
      expect(result).to include(general_tag, artist_tag)
      expect(result).not_to include(meta_tag)
    end
  end

  describe "order param" do
    it "orders by created_at descending" do
      ids = Tag.search(order: "created_at").ids
      expect(ids.index(newer.id)).to be < ids.index(older.id)
    end
  end
end
```

### Audit logging (ModAction)

```ruby
describe "#log_create" do
  it "logs a create action when a record is created" do
    feedback = create(:user_feedback)
    log = ModAction.last
    expect(log.action).to eq("user_feedback_create")
    # Use log[:values] (raw jsonb) to bypass CurrentUser-based field filtering
    expect(log[:values]).to include("user_id" => user.id, "record_id" => feedback.id)
  end
end

describe "#log_update" do
  it "logs only user_feedback_delete when soft-deleting" do
    feedback = create(:user_feedback)
    expect { feedback.update!(is_deleted: true) }.to change(ModAction, :count).by(1)
    expect(ModAction.last.action).to eq("user_feedback_delete")
  end

  it "logs user_feedback_delete then user_feedback_update when deleting with body change" do
    feedback = create(:user_feedback)
    expect { feedback.update!(is_deleted: true, body: "updated") }.to change(ModAction, :count).by(2)
    expect(ModAction.last(2).map(&:action)).to eq(%w[user_feedback_delete user_feedback_update])
  end
end

describe "#log_destroy" do
  it "logs a destroy action on hard-delete" do
    feedback = create(:user_feedback)
    feedback_id = feedback.id        # capture before freeze
    feedback.destroy!
    expect(ModAction.last.action).to eq("user_feedback_destroy")
    expect(ModAction.last[:values]).to include("record_id" => feedback_id)
  end
end
```

### Shared examples

When two models share a large surface area (e.g. `TagAlias` / `TagImplication`), extract them into `spec/support/shared_examples/`:

```ruby
# In spec/support/shared_examples/my_examples.rb
RSpec.shared_examples "my group" do |factory_name, model_class|
  let(:record) { create(factory_name) }

  describe "#something" do
    it "does X" do
      expect(record.something).to eq("X")
    end
  end
end

# In the model spec
RSpec.describe TagAlias, type: :model do
  it_behaves_like "my group", :tag_alias, TagAlias
end
```

Helper methods inside shared examples are defined as plain `def` (available within the example group):

```ruby
def make_with_status(factory_name, status)
  create(factory_name).tap { |r| r.update_columns(status: status) }
end
```

---

## Matcher Cheat-Sheet

```ruby
# Validity
expect(record).to be_valid
expect(record).not_to be_valid

# Errors
expect(record.errors[:field]).to be_present
expect(record.errors[:base]).to include("exact error string")

# Collections
expect(result).to include(a, b)
expect(result).not_to include(c)

# Equality
expect(record.field).to eq("value")

# Truthiness
expect(predicate).to be true     # exactly true
expect(predicate).to be false    # exactly false
expect(predicate).to be_truthy   # any truthy value
expect(predicate).to be_falsy    # nil or false

# Change
expect { action }.to change { record.reload.field }.from(old).to(new)
expect { action }.to change(ModelClass, :count).by(1)
expect { action }.not_to raise_error

# Ordering
expect(ids.index(newer.id)).to be < ids.index(older.id)

# Nil
expect(record.field).to be_nil
```

---

## Common Gotchas

| Problem | Solution |
|---------|----------|
| Level-predicate methods return wrong value | Use `create(...)` not `build(...)` — `is_admin?` etc. query the DB |
| `CurrentUser` not set | Use `include_context "as <role>"` or set it manually in `before`/`after` |
| Validation runs unexpectedly on update | Use `update_columns(...)` to bypass callbacks and validations |
| ModAction values filtered by level | Read `log[:values]` (raw jsonb) instead of `log.values` |
| Two records get the same sequence value | Don't hardcode names in factories — let sequences generate them |
| Sock puppet validation fires in factory | Already disabled globally in the `:user` factory's `after(:build)` hook |
| Order-dependent test failures | Each run uses `--order random`; avoid relying on insertion order without explicit `order` calls |
| `allow(Danbooru.config).to receive(:x)` raises "does not implement" | `Danbooru.config` delegates via `method_missing` — stub on `Danbooru.config.custom_configuration` instead: `allow(Danbooru.config.custom_configuration).to receive(:pool_post_limit).and_return(3)` |
