# frozen_string_literal: true

require "test_helper"

class PaginatorTest < ActiveSupport::TestCase
  def assert_paginated(expected_records:, is_first_page:, is_last_page:, &)
    records = yield
    assert_equal(expected_records.map(&:id), records.map(&:id))
    assert_equal(is_first_page, records.is_first_page?, "is_first_page")
    assert_equal(is_last_page, records.is_last_page?, "is_last_page")
  end

  { active_record: Blip, opensearch: Post }.each do |type, model| # rubocop:disable Metrics/BlockLength
    context type do
      setup do
        @user = create(:user)
        CurrentUser.user = @user
      end

      context "sequential pagination (before)" do
        should "return the correct set of records" do
          @records = create_list(model.name.underscore, 4)
          assert_paginated(expected_records: [], is_first_page: false, is_last_page: true) { model.paginate("b#{@records[0].id}", limit: 2) }
          assert_paginated(expected_records: [@records[0]], is_first_page: false, is_last_page: true) { model.paginate("b#{@records[1].id}", limit: 2) }
          assert_paginated(expected_records: [@records[1], @records[0]], is_first_page: false, is_last_page: true) { model.paginate("b#{@records[2].id}", limit: 2) }
          assert_paginated(expected_records: [@records[2], @records[1]], is_first_page: false, is_last_page: false) { model.paginate("b#{@records[3].id}", limit: 2) }
          assert_paginated(expected_records: [@records[3], @records[2]], is_first_page: false, is_last_page: false) { model.paginate("b999999999", limit: 2) }
        end
      end

      context "sequential pagination (after)" do
        should "return the correct set of records" do
          @records = create_list(model.name.underscore, 4)
          assert_paginated(expected_records: [@records[1], @records[0]], is_first_page: false, is_last_page: false) { model.paginate("a0", limit: 2) }
          assert_paginated(expected_records: [@records[2], @records[1]], is_first_page: false, is_last_page: false) { model.paginate("a#{@records[0].id}", limit: 2) }
          assert_paginated(expected_records: [@records[3], @records[2]], is_first_page: true, is_last_page: false) { model.paginate("a#{@records[1].id}", limit: 2) }
          assert_paginated(expected_records: [@records[3]], is_first_page: true, is_last_page: false) { model.paginate("a#{@records[2].id}", limit: 2) }
          assert_paginated(expected_records: [], is_first_page: true, is_last_page: false) { model.paginate("a#{@records[3].id}", limit: 2) }
        end
      end

      context "numbered pagination" do
        setup do
          skip "flaky af" if ENV["CI"] && type == :opensearch
        end

        should "return the correct set of records" do
          @records = create_list(model.name.underscore, 4)
          assert_paginated(expected_records: [@records[0]], is_first_page: true, is_last_page: false) { model.paginate("1", limit: 1) }
          assert_paginated(expected_records: [@records[1]], is_first_page: false, is_last_page: false) { model.paginate("2", limit: 1) }
          assert_paginated(expected_records: [@records[2]], is_first_page: false, is_last_page: false) { model.paginate("3", limit: 1) }
          assert_paginated(expected_records: [@records[3]], is_first_page: false, is_last_page: true) { model.paginate("4", limit: 1) }
          assert_paginated(expected_records: [], is_first_page: false, is_last_page: true) { model.paginate("5", limit: 1) }
        end

        should "return the correct set of records when only one result exists" do
          @records = create_list(model.name.underscore, 2)
          assert_paginated(expected_records: [@records[0], @records[1]], is_first_page: true, is_last_page: true) { model.paginate("1", limit: 2) }
        end
      end
    end
  end
end
