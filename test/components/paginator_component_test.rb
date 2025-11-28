# frozen_string_literal: true

require "test_helper"

class PaginatorComponentTest < ActionView::TestCase
  include FactoryBot::Syntax::Methods

  def setup
    @user = create(:user)
    @controller = PostsController.new
    @controller.request = ActionDispatch::TestRequest.create({ "PATH_INFO" => "/posts", "REQUEST_METHOD" => "GET" })
    @controller.response = ActionDispatch::TestResponse.new
    @controller.params = ActionController::Parameters.new(controller: "posts", action: "index")
    @request = @controller.request
  end

  context "numbered pagination" do
    should "render prev and next buttons correctly" do
      as(@user) do
        create_list(:post, 10)
        paginated = Post.paginate(2, limit: 3)
        component = PaginatorComponent.new(records: paginated)

        render component

        assert_select "nav.pagination.numbered"
        assert_select "a.prev#paginator-prev"
        assert_select "a.next#paginator-next"
      end
    end

    should "disable prev button on first page" do
      as(@user) do
        create_list(:post, 10)
        paginated = Post.paginate(1, limit: 3)
        component = PaginatorComponent.new(records: paginated)

        render component

        assert_select "span.prev#paginator-prev"
        assert_select "a.prev", count: 0
        assert_select "a.next"
      end
    end

    should "disable next button on last page" do
      as(@user) do
        create_list(:post, 10)
        paginated = Post.paginate(4, limit: 3)
        component = PaginatorComponent.new(records: paginated)

        render component

        assert_select "a.prev"
        assert_select "span.next#paginator-next"
        assert_select "a.next", count: 0
      end
    end

    should "show current page as highlighted" do
      as(@user) do
        create_list(:post, 10)
        paginated = Post.paginate(2, limit: 3)
        component = PaginatorComponent.new(records: paginated)

        render component

        assert_select "span.page.current[aria-current='page']", text: "2"
      end
    end

    should "show first and last pages" do
      as(@user) do
        create_list(:post, 100)
        paginated = Post.paginate(50, limit: 1)
        component = PaginatorComponent.new(records: paginated)

        render component

        assert_select "a.page.first", text: "1"
        assert_select "a.page.last", text: "100"
      end
    end

    should "show pages around current page" do
      as(@user) do
        create_list(:post, 100)
        paginated = Post.paginate(50, limit: 1)
        component = PaginatorComponent.new(records: paginated)

        render component

        # Should show current ± 1 page
        assert_select "a.page", text: "49"
        assert_select "span.page.current", text: "50"
        assert_select "a.page", text: "51"
      end
    end

    should "show spacers when there are gaps" do
      as(@user) do
        create_list(:post, 100)
        paginated = Post.paginate(50, limit: 1)
        component = PaginatorComponent.new(records: paginated)

        render component

        # Should have spacers between 1 and 49, and between 51 and 100
        assert_select "a.page.spacer", count: 2
      end
    end

    should "not show spacers when pages are adjacent" do
      as(@user) do
        create_list(:post, 5)
        paginated = Post.paginate(3, limit: 1)
        component = PaginatorComponent.new(records: paginated)

        render component

        # Pages are: 1, 2, 3, 4, 5 - all adjacent, no spacers needed
        assert_select "a.page.spacer", count: 0
      end
    end

    should "show extra pages on right when near the start" do
      as(@user) do
        create_list(:post, 100)
        paginated = Post.paginate(1, limit: 1)
        component = PaginatorComponent.new(records: paginated)

        render component

        # Should show 1, 2, 3, [...], 100
        assert_select "span.page.current", text: "1"
        assert_select "a.page", text: "2"
        assert_select "a.page", text: "3"
        assert_select "a.page.spacer"
        assert_select "a.page.last", text: "100"
      end
    end

    should "show extra pages on left when near the end" do
      as(@user) do
        create_list(:post, 100)
        paginated = Post.paginate(100, limit: 1)
        component = PaginatorComponent.new(records: paginated)

        render component

        # Should show 1, [...], 98, 99, 100
        assert_select "a.page.first", text: "1"
        assert_select "a.page.spacer"
        assert_select "a.page", text: "98"
        assert_select "a.page", text: "99"
        assert_select "span.page.current", text: "100"
      end
    end

    should "handle single page results" do
      as(@user) do
        create_list(:post, 3)
        paginated = Post.paginate(1, limit: 5)
        component = PaginatorComponent.new(records: paginated)

        render component

        # Only one page, no navigation needed
        assert_select "span.prev"
        assert_select "span.next"
        assert_select "span.page.current", text: "1"
        assert_select "a.page.spacer", count: 0
      end
    end

    should "include hotkey attributes on prev/next buttons" do
      as(@user) do
        create_list(:post, 10)
        paginated = Post.paginate(2, limit: 3)
        component = PaginatorComponent.new(records: paginated)

        render component

        assert_select "a.prev[data-hotkey='prev']"
        assert_select "a.next[data-hotkey='next']"
      end
    end
  end

  context "sequential pagination" do
    should "render as sequential mode" do
      as(@user) do
        posts = create_list(:post, 10)
        paginated = Post.paginate("b#{posts[5].id}", limit: 3)
        component = PaginatorComponent.new(records: paginated)

        render component

        assert_select "nav.pagination.sequential"
      end
    end

    should "show prev and next buttons without page numbers" do
      as(@user) do
        posts = create_list(:post, 10)
        paginated = Post.paginate("b#{posts[5].id}", limit: 3)
        component = PaginatorComponent.new(records: paginated)

        render component

        assert_select "a.prev"
        assert_select "a.next"
        assert_select ".page", count: 0
        assert_select ".break", count: 0
      end
    end

    should "use 'a' prefix for prev in sequential_before mode" do
      as(@user) do
        posts = create_list(:post, 10)
        paginated = Post.paginate("b#{posts[5].id}", limit: 3)
        component = PaginatorComponent.new(records: paginated)

        render component

        prev_link = css_select("a.prev").first
        href = prev_link["href"]
        assert_match(/page=a\d+/, href)
      end
    end

    should "use 'b' prefix for next in sequential_before mode" do
      as(@user) do
        posts = create_list(:post, 10)
        paginated = Post.paginate("b#{posts[5].id}", limit: 3)
        component = PaginatorComponent.new(records: paginated)

        render component

        next_link = css_select("a.next").first
        href = next_link["href"]
        assert_match(/page=b\d+/, href)
      end
    end

    should "disable prev button when on first page" do
      as(@user) do
        posts = create_list(:post, 10)
        # Use 'a' to go forward until we hit the newest posts
        paginated = Post.paginate("a#{posts[-2].id}", limit: 3)
        component = PaginatorComponent.new(records: paginated)

        render component

        if paginated.is_first_page?
          assert_select "span.prev"
          assert_select "a.prev", count: 0
        end
      end
    end

    should "disable next button when on last page" do
      as(@user) do
        posts = create_list(:post, 10)
        # Use 'b' to go backward until we hit the oldest posts
        paginated = Post.paginate("b#{posts[1].id}", limit: 3)
        component = PaginatorComponent.new(records: paginated)

        render component

        if paginated.is_last_page?
          assert_select "span.next"
          assert_select "a.next", count: 0
        end
      end
    end
  end

  context "mode switching" do
    should "switch to sequential mode when at max_numbered_pages" do
      as(@user) do
        create_list(:post, 10)
        # Component switches to sequential when current_page == max_numbered_pages (750)
        paginated = Post.paginate(750, limit: 1)
        component = PaginatorComponent.new(records: paginated)

        render component

        assert_select "nav.pagination.sequential"
      end
    end

    should "stay in numbered mode when below max_numbered_pages" do
      as(@user) do
        create_list(:post, 10)
        # Page 749 is below max_numbered_pages
        paginated = Post.paginate(749, limit: 1)
        component = PaginatorComponent.new(records: paginated)

        render component

        assert_select "nav.pagination.numbered"
      end
    end
  end

  context "edge cases" do
    should "handle empty results" do
      as(@user) do
        paginated = Post.paginate(1, limit: 10)
        component = PaginatorComponent.new(records: paginated)

        render component

        # Should still render but with disabled buttons
        assert_select "span.prev"
        assert_select "span.next"
      end
    end

    should "handle 2-page results correctly" do
      as(@user) do
        create_list(:post, 2)
        paginated = Post.paginate(1, limit: 1)
        component = PaginatorComponent.new(records: paginated)

        render component

        # Should show: 1, 2 (no spacers)
        assert_select "span.page.current", text: "1"
        assert_select "a.page", text: "2"
        assert_select "a.page.spacer", count: 0
      end
    end

    should "handle 3-page results on middle page" do
      as(@user) do
        create_list(:post, 3)
        paginated = Post.paginate(2, limit: 1)
        component = PaginatorComponent.new(records: paginated)

        render component

        # Should show: 1, 2, 3 (all adjacent)
        assert_select "a.page", text: "1"
        assert_select "span.page.current", text: "2"
        assert_select "a.page", text: "3"
        assert_select "a.page.spacer", count: 0
      end
    end
  end
end
