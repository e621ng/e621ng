# e621ng vs e6AI — Known Differences

This document records fork-specific divergences discovered while making the test suite
portable across both codebases. Use it as a reference when writing new specs or porting
changes between forks.

---

## Tag Categories

The integer IDs are **identical** in both forks. Only the names differ.

| ID | e621ng name  | e6AI name     |
|----|-------------|---------------|
| 0  | general     | general       |
| 1  | **artist**  | **director**  |
| 2  | contributor | *(removed)*   |
| 3  | **copyright** | **franchise** |
| 4  | character   | character     |
| 5  | species     | species       |
| 6  | invalid     | invalid       |
| 7  | meta        | meta          |
| 8  | lore        | lore          |

Category 2 (`contributor`) does not exist in e6AI at all — it is absent from every
mapping constant (`CANONICAL_MAPPING`, `REVERSE_MAPPING`, `SHORT_NAME_MAPPING`, etc.).

### Derived names that change with category renames

| Context              | e621ng              | e6AI                |
|----------------------|---------------------|---------------------|
| Tag prefix           | `artist:`, `copyright:` | `director:`, `franchise:` |
| Short-name metatag   | `arttags`, `copytags`, `contribtags` | `dirtags`, `franctags` *(no contrib)* |
| Tag count column     | `tag_count_artist`, `tag_count_copyright`, `tag_count_contributor` | `tag_count_director`, `tag_count_franchise` *(no contrib)* |
| Post method          | `post.artist_tags`  | `post.director_tags` |
| Wiki page prefix     | `"Artist: …"`       | `"Director: …"`     |
| Order metatag        | `order:arttags`     | `order:dirtags`     |

### How to write portable specs

Use constants rather than hardcoded names:

```ruby
TagCategory::REVERSE_MAPPING[1]          # "artist" or "director"
TagCategory::REVERSE_MAPPING[3]          # "copyright" or "franchise"
TagCategory::SHORT_NAME_MAPPING          # all short-name → full-name pairs
TagCategory::REVERSE_MAPPING.values      # all full category names
```

Use integer IDs directly when you only need to set or compare a category value — the
IDs are stable across forks:

```ruby
create(:tag, category: 1)   # category-1 tag, regardless of fork
expect(tag.category).to eq(1)
```

---

## Missing Routes

The following controllers exist in both forks (models and controller files are present) but are **not routed** in e6AI's `routes.rb`:

- `ArtistsController`
- `ArtistVersionsController`
- `ArtistUrlsController`
- `AvoidPostingsController`
- `AvoidPostingVersionsController`
- `BlipsController`

Any request spec for these controllers will raise a routing error on e6AI.

### How to write portable specs

Add a `before` guard at the top of the `RSpec.describe` block that checks whether the route helper is defined:

```ruby
RSpec.describe ArtistsController do
  before { skip "Artists routes not available in this fork" unless Rails.application.routes.url_helpers.respond_to?(:artists_path) }
  # …
end
```

Rails only defines route helper methods (e.g. `artists_path`) when the route is declared in `routes.rb`. If it is absent, `method_defined?` returns false and every example in the block is skipped. The pattern generalises to any controller: pick the index path helper (`<resource>_path`) as the sentinel.

---

## Post Model Behavior

| Feature | e621ng | e6AI |
|---------|--------|------|
| `has_artist_tag` warning validator | active | **commented out** |
| `NON_KNOWN_ARTIST_TAGS` constant | `["unknown_artist", …]` | `["unknown_director", …]` |
| `known_artist_tags` method | present | present (same name) |

The `has_artist_tag` validator difference cannot be detected at runtime (it is
commented-out code, not a config flag). Tests covering that warning should be skipped
in the e6AI spec copy with an explicit `skip` and explanation.
