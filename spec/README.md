# e621ng Test Suite

For patterns, conventions, and copy-paste examples when writing new tests, see [PATTERNS.md](PATTERNS.md).

## Technologies

| Tool | Version | Purpose |
|------|---------|---------|
| [RSpec Rails](https://github.com/rspec/rspec-rails) | ~8.0.0 | Test framework |
| [FactoryBot Rails](https://github.com/thoughtbot/factory_bot_rails) | latest | Test data factories |
| [SimpleCov](https://github.com/simplecov-ruby/simplecov) | latest | Code coverage (HTML + JSON) |
| [simplecov_json_formatter](https://github.com/vicentllongo/simplecov-json) | latest | JSON formatter for SimpleCov |
| [Faker](https://github.com/faker-ruby/faker) | latest | Fake data generation |
| [parallel_tests](https://github.com/grosser/parallel_tests) | >=4.0 | Parallel test execution |


## Configuration Highlights

- **Transactional fixtures** — each test runs in a rolled-back transaction.
- **Randomized order** — tests are shuffled on every run to surface ordering dependencies. Use `--seed N` to reproduce a specific run.
- **Profiling** — the 10 slowest examples and groups are reported at the end of each run.
- **Sock puppet validation** is globally disabled in `before(:each)` so factories can create users without triggering IP uniqueness checks.
- **SimpleCov** outputs HTML and JSON reports to `coverage/`. Parallel workers merge their results automatically using `TEST_ENV_NUMBER`.


## Running Tests

Tests run inside Docker via `docker compose`. The `tests` service uses `parallel_rspec` with `PARALLEL_TEST_PROCESSORS` workers (default: 4).

```sh
# Full suite (parallel)
docker compose run --rm tests

# Subset of specs — pass paths as arguments
docker compose run --rm tests spec/models/setting/
docker compose run --rm tests spec/models/user_feedback/validations_spec.rb

# Reproduce a specific random order — pass --seed via the rspec options env var
RSPEC_OPTS="--seed 1234" docker compose run --rm tests
```

Coverage reports are written to `coverage/` after each run.
