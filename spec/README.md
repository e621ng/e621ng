# e621ng RSpec Patterns & Conventions

This document covers only codebase-specific conventions. Standard RSpec/FactoryBot knowledge is assumed.

---

## Technologies

| Tool | Version | Purpose |
|------|---------|---------|
| [RSpec Rails](https://github.com/rspec/rspec-rails) | ~8.0.0 | Test framework |
| [FactoryBot Rails](https://github.com/thoughtbot/factory_bot_rails) | latest | Test data factories |
| [SimpleCov](https://github.com/simplecov-ruby/simplecov) | latest | Code coverage (HTML + JSON) |
| [simplecov_json_formatter](https://github.com/vicentllongo/simplecov-json) | latest | JSON formatter for SimpleCov |
| [Faker](https://github.com/faker-ruby/faker) | latest | Fake data generation |
| [parallel_tests](https://github.com/grosser/parallel_tests) | >=4.0 | Parallel test execution |

---

## Running Tests and Linting

Tests run inside Docker via `docker compose`. The `tests` service uses `parallel_rspec` with `PARALLEL_TEST_PROCESSORS` workers (default: 4). Coverage reports are written to `coverage/` after each run.

```bash
# Full suite (parallel)
docker compose run --rm tests

# Run a spec file or directory
docker compose run --rm tests spec/requests/blips_controller_spec.rb

# Reproduce a specific random order
RSPEC_OPTS="--seed 1234" docker compose run --rm tests

# Run RuboCop on a spec file or directory
docker compose run --rm rubocop spec/requests/blips_controller_spec.rb
```

---

## Directory Structure

```
spec/
├── factories/
├── models/{model}/
│   ├── factory_spec.rb
│   ├── validations_spec.rb
│   ├── normalizations_spec.rb
│   ├── instance_methods_spec.rb
│   ├── permissions_spec.rb
│   ├── scopes_spec.rb
│   ├── search_spec.rb
│   ├── log_methods_spec.rb
│   └── {domain}_methods_spec.rb
├── middleware/
├── logical/
├── support/
│   ├── shared_examples/
│   ├── current_user_contexts.rb
│   └── tag_categories.rb
└── fixtures/
```

---

## rails_helper.rb Highlights

- `before(:suite)` seeds: `admin` user, system user (`Danbooru.config.system_user`), `ForumCategory` "Tag Alias and Implication Suggestions"
- All files in `spec/support/**/*.rb` are auto-required
- **Transactional fixtures** — each test runs in a rolled-back transaction
- **Randomized order** — tests are shuffled every run to surface ordering dependencies; use `--seed N` to reproduce
- **Profiling** — the 10 slowest examples and groups are reported at the end of each run
- **Sock puppet validation** is globally disabled in `before(:each)` so factories can create users without triggering IP uniqueness checks
- **SimpleCov** outputs HTML and JSON reports to `coverage/`; parallel workers merge results automatically via `TEST_ENV_NUMBER`

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

Provides lazy `let` helpers: `general_tag_category` (0), `artist_tag_category` (1), `copyright_tag_category` (3), `character_tag_category` (4), `species_tag_category` (5), `invalid_tag_category` (6), `meta_tag_category` (7), `lore_tag_category` (8).

---

## Factory Patterns

### Sequences

```ruby
# Global
sequence(:tag_name) { |n| "tag_#{n}" }

# Inline (scoped to factory)
factory :tag_alias do
  sequence(:antecedent_name) { |n| "antecedent_tag_#{n}" }
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
association :creator, factory: :user

# Force persistence (required when level predicates must return true — they query the DB)
creator { create(:moderator_user) }
```

### Sock puppet validation

The `:user` factory disables sock-puppet validation by default via a transient + `after(:build)` hook. Opt back in with `create(:user, disable_sock_puppet_validation: false)`.

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
RSpec.describe ModelName do
  include_context "as admin"
  # ...
end
```

**Do not pass `type: :model`** — RuboCop (`RSpecRails/InferredSpecType`) flags it as redundant; the type is inferred from the file path.

---

## Patterns by Concern

### Validations

Use `build` (not `create`) so no DB write occurs. Assert `not_to be_valid` and that `errors[:field]` is present.

Trigger `before_validation` without persisting by calling `record.valid?` directly.

### Normalizations

Use `create` and assert the stored value. For `before_validation` transforms, call `record.valid?` and assert the in-memory attribute without saving.

### Scopes

Use `let!` for records that must exist before the example runs (exclusion tests, ordering tests). Assert inclusion and exclusion explicitly.

### Instance methods

Use `update_columns` to set state that should bypass callbacks. Use `record.reload` after mutations to assert the persisted value.

### Permissions

Test the exact boundary conditions (role, ownership, time window). Use `be true` / `be false` rather than `be_truthy` / `be_falsy`.

### Search

Test each param in isolation. Use wildcard and case variants where the implementation supports them.

### Audit logging (ModAction)

Use `log[:values]` (raw jsonb) instead of `log.values` — `log.values` filters fields based on `CurrentUser` level.

```ruby
it "logs a create action" do
  feedback = create(:user_feedback)
  expect(ModAction.last.action).to eq("user_feedback_create")
  expect(ModAction.last[:values]).to include("record_id" => feedback.id)
end
```

Capture `record.id` before `destroy!` — it is unavailable after.

### Shared examples

Place in `spec/support/shared_examples/`. Helper methods inside shared examples are plain `def` (scoped to the example group).

---

## RuboCop Rules (non-obvious)

### RSpec/VerifiedDoubles — use `instance_spy` / `instance_double`

```ruby
# BAD
storage = double("storage_manager")

# GOOD
storage = instance_spy(StorageManager)   # all methods stubbed, unknown calls don't raise
storage = instance_double(StorageManager) # unknown calls raise
```

### RSpec/ReceiveMessages — collapse stubs on the same object

```ruby
# BAD
allow(user).to receive(:favorite_limit).and_return(0)
allow(user).to receive(:favorite_count).and_return(0)

# GOOD
allow(user).to receive_messages(favorite_limit: 0, favorite_count: 0)
```

### RSpec/MessageSpies — allow first, assert after

```ruby
# BAD
expect(storage).to receive(:delete_video_samples).with(post.md5)
subject.delete_video_samples!

# GOOD
subject.delete_video_samples!
expect(storage).to have_received(:delete_video_samples).with(post.md5)
```

Full pattern for delegation tests:

```ruby
it "delegates to storage_manager" do
  post    = create(:post)
  storage = instance_spy(StorageManager)
  allow(post).to receive(:storage_manager).and_return(storage)
  post.large_file_path
  expect(storage).to have_received(:post_file_path).with(post, :large)
end
```

---

## Common Gotchas

| Problem | Solution |
|---------|----------|
| Level predicates return wrong value | Use `create(...)` not `build(...)` — `is_admin?` etc. query the DB |
| `CurrentUser` not set | Use `include_context "as <role>"` or set manually in `before`/`after` |
| ModAction values filtered by level | Read `log[:values]` (raw jsonb) instead of `log.values` |
| `allow(Danbooru.config).to receive(:x)` raises "does not implement" | `Danbooru.config` delegates via `method_missing` — stub on the inner object: `allow(Danbooru.config.custom_configuration).to receive(:pool_post_limit).and_return(3)` |
| `save!(validate: false)` raises `NotNullViolation` on `creator_id` / `creator_ip_addr` | `belongs_to_creator` sets these in a `before_validation on: :create` callback, which is skipped. Set them explicitly: `t.creator_id = CurrentUser.id; t.creator_ip_addr = CurrentUser.ip_addr` |
| Order-dependent failures | Tests run with `--order random`; never rely on insertion order without an explicit `order` call |
