# Development data

The `populate:*` rake tasks fill a development database. They either import real,
public data from the site's database exports or generate fake data with Faker.
The code lives in this directory; the task definitions are in
[`lib/tasks/populate.rake`](../../lib/tasks/populate.rake). Design notes:
knowledgebase design doc 44.

Run the tasks inside the `e621` container. The `rails_dev` service does not mount
the post data volume, so media written from it is never served.

```sh
docker exec -it e621ng-e621-1 bin/populate posts COUNT=1000
docker exec -it e621ng-e621-1 bin/rails populate:posts COUNT=1000   # same thing
```

`bin/populate` takes task names without the `populate:` prefix, runs several in
order, and passes `KEY=VALUE` arguments through as environment variables. With no
arguments it runs `populate:all`.

## Quick start

1. Download the `.csv.gz` files from the site's database exports page
   (`/db_exports`) into `db/exports/`, next to the `.sql` files that produce them.
   They are gitignored. `post_versions.csv.gz` is optional and large.
2. Import the reference data and some posts:

   ```sh
   bin/populate exports:load tags wiki artists burs
   bin/populate posts COUNT=10000 QUERY="score:>150 -rating:e -young"
   ```

3. Optionally add fake activity on top: `bin/populate comments favorites forums`.

Without the exports, `bin/populate` still works: `populate:all` notices the
missing posts export and imports its posts through the live API and the upload
pipeline instead, which takes a few seconds per post.

## Tasks

| Task | What it does | Environment |
|---|---|---|
| `exports:load` | Copies the exports into the `seed` schema. Each importer also loads what it needs on first use. | `TABLES` (comma list, default all but `post_versions`), `EXPORTS_DIR`, `FORCE=1` |
| `tags` | Every tag, alias and implication, with production post counts. | `FIX_COUNTS=1` |
| `wiki`, `artists`, `burs` | Every wiki page, artist (with URLs) and bulk update request. | `EXPORTS_DIR` |
| `posts` | Posts from the exports, with their pools, replacements and history. | see [Posts](#posts) |
| `pools`, `replacements`, `versions` | The same relations for posts imported earlier. `versions` loads the `post_versions` export if needed. | `POOL_MIN`; `MEDIA=none` for replacements |
| `media` | Media for posts that lack it. | `TIER=placeholder\|fetch`, `COUNT` (1000), `FORCE=1`, `FETCH_THREADS`, `MEDIA_THREADS`, `ORIGINALS=1` |
| `reindex` | Bulk-indexes posts and post versions into OpenSearch. | `FROM`, `TO` (post ids) |
| `users`, `comments`, `favorites`, `forums`, `post_votes`, `comment_votes`, `dmails` | Faker data. | `COUNT`, `DISTRIBUTION`; `PASSWORD` for users |
| `avatars` | Gives users without an avatar a random post. | `COUNT` |
| `trends` | Search trend rows. | `DAYS`, `HOURS`, `TAGS` |
| `all` | Users, posts, avatars, Faker activity and trends in one go. | `USERS`, `POSTS`, `COMMENTS`, `FAVORITES`, `FORUMS`, `POSTVOTES`, `COMVOTES`, `FURIDS`, `DM`, `TRENDS`, `TRENDS_HOURS`, `SOURCE=api` |

Every importer is idempotent: running it again inserts nothing new.

## Exports and the `seed` schema

`exports:load` streams each `.csv.gz` into a table of the same name in a `seed`
schema of the development database, indexes it and analyzes it. A file is only
reloaded when its size or modification time changes, or with `FORCE=1`. The schema
is excluded from `db/structure.sql` dumps.

To start over, drop it: `bin/rails runner 'ActiveRecord::Base.connection.execute("DROP SCHEMA seed CASCADE")'`.

Measured on a 16-core workstation (Docker on WSL2):

| Export | Rows | Load |
|---|---|---|
| tags | 1.6M | 3 s |
| posts | 6.9M | 88 s |
| post_versions (opt-in, 9 GB) | 47.1M | 11 min |
| everything else | under 350k each | under 3 s each |

## Posts

```sh
bin/populate posts COUNT=10000 QUERY="score:>150 -rating:e -young -type:swf"
```

| Variable | Default | Meaning |
|---|---|---|
| `COUNT` | 100 | How many posts, newest first. |
| `RANGE` | none | `lo..hi`: only post ids in this range. A contiguous range gives coherent pools and parent/child chains. |
| `QUERY` | `score:>150 -grandfathered_content -rating:e -young -type:swf` | Filter, see below. Pass `QUERY=` for none. |
| `MEDIA` | `placeholder` | `placeholder`, `fetch` or `none`; see [Media](#media). |
| `MEDIA_THREADS` | CPU count, 2–16 | Placeholder workers. |
| `FETCH_THREADS` | 8 | Connections to static1 for `MEDIA=fetch`. |
| `ORIGINALS` | off | With `MEDIA=fetch`, download every original. |
| `POOL_MIN` | 3 | A pool comes along once this many of its posts are imported (or all of them, for smaller pools). 0 skips pools. |
| `REINDEX` | on | Bulk-index the imported posts into OpenSearch. |
| `SOURCE` | `export` | `api` uses the live site's API and the full upload pipeline instead (slow, real files). `SEARCH` sets the API query. |

`QUERY` is a small filter, not the site's tag search. Tokens are separated by spaces
and combined with AND:

- `tag`, `-tag`
- `rating:s|q|e`, `-rating:e`; `type:png`, `-type:swf`
- `score:`, `favcount:`, `id:`, `width:`, `height:`, `filesize:` with `N`, `>N`, `>=N`, `<N`, `<=N` or `lo..hi`
- `date:` with the same comparisons on `YYYY-MM-DD`
- `status:active|pending|deleted|flagged|any`
- `parent:none|any|N`

What comes with each post:

- its direct parent, if the export has it;
- a synthetic first version, replaced by the real history when the
  `post_versions` export is loaded;
- its pools, trimmed to the posts present locally and grown as more arrive;
- its approved replacements and original backup, with placeholder files;
- placeholder uploader and approver accounts named `user_<id>`, with their post,
  deletion and edit counts. Their password is `hexerade`.

A post counts as imported only when both its id and its md5 match the export.
Posts seeded through `SOURCE=api` keep local ids that belong to unrelated
production posts, so no production pools or history are attached to them.

Tags keep their production `post_count`, which keeps autocomplete and related-tag
ordering realistic. `bin/populate tags FIX_COUNTS=1` recounts every tag from the
undeleted local posts instead (about two minutes for the full tag table).

## Media

Imported posts have no files until a media tier writes them.

**`placeholder`** (default, offline). A flat-colour image per post, coloured from its
md5, plus previews and samples with the real geometry. Videos get a one-second clip
of the same colour. Flash posts get nothing, as on the site. About 35 posts a second
with 16 workers: 10,000 posts take roughly five minutes.

**`fetch`** (needs network). Downloads the real preview and sample of each post from
static1, and the original when the post has no sample, because that is what its page
shows. `ORIGINALS=1` downloads every original. Deleted posts (signed on static1) and
posts static1 does not have get placeholders and are retried on the next fetch run.
Legacy posts without webp variants get them converted locally. About 43 posts a second
at 8 connections, roughly 0.5 MB per post. `bin/populate media TIER=fetch COUNT=…`
upgrades posts that already have placeholders.

**`none`**. No files. Useful for data-only work, or with the recipe below.

Replacement files are always placeholders: static1 only serves them signed.

### Serving imported posts from static1

To browse real images without downloading them, import with `MEDIA=none` and override
the storage manager in `config/danbooru_local_config.rb` (mounted from
`docker/danbooru_local_config.rb` in Docker). Posts whose original exists locally are
served locally; everything else links to static1.

```ruby
module Danbooru
  class CustomConfiguration < Configuration
    def storage_manager
      base_dir = Rails.public_path.join("data").to_s
      remote = StorageManager::Local.new(base_url: "https://static1.e621.net", base_dir: base_dir, hierarchical: true)
      local = StorageManager::Local.new(base_dir: base_dir, hierarchical: true)
      local.define_singleton_method(:post_file_url) do |post, type = :original, **options|
        File.exist?(post_file_path(post)) ? super(post, type, **options) : remote.post_file_url(post, type, **options)
      end
      local
    end
  end
end
```

Every page view then loads images from the production CDN. Deleted posts do not load,
and anything that reads the file itself fails for remote posts: replacements,
thumbnail regeneration, IQDB, avatar cropping.

## Gotchas

- **Name conflicts.** Importers skip rows whose name or id already exists locally, so
  a tag you created before importing keeps its local id and count.
- **Synthetic versions.** Without the `post_versions` export each post has one
  version by its uploader. `bin/populate versions` replaces them later.
- **Sequences.** Imports move the id sequences past the imported ids, so local
  uploads and edits never collide with production ids.
- **OpenSearch.** Raw inserts skip the indexing callbacks. `posts`, `pools` and
  `versions` reindex what they touch; after anything else, run `bin/populate reindex`.
