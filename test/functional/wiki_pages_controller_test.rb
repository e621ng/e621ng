# frozen_string_literal: true

require("test_helper")

class WikiPagesControllerTest < ActionDispatch::IntegrationTest
  context("The wiki pages controller") do
    setup do
      @user = create(:user)
      @privileged = create(:privileged_user)
      @mod = create(:moderator_user)
      @admin = create(:admin_user)
      @tag = create(:tag)
      @wiki_page = as(@user) { create(:wiki_page, title: @tag.name) }
    end

    context("index action") do
      setup do
        as(@user) do
          @wiki_page_abc = create(:wiki_page, title: "abc")
          @wiki_page_def = create(:wiki_page, title: "def")
        end
      end

      should("render") do
        get(wiki_pages_path)
        assert_response(:success)
      end

      should("redirect with title search") do
        get(wiki_pages_path, params: { search: { title: "abc" } })
        assert_redirected_to(wiki_page_path(@wiki_page_abc))
      end

      should("list wiki_pages without tags with order=post_count") do
        get(wiki_pages_path, params: { search: { title: "abc", order: "post_count" } })
        assert_redirected_to(wiki_page_path(@wiki_page_abc))
      end
    end

    context("show action") do
      should("render") do
        get(wiki_page_path(@wiki_page))
        assert_response(:success)
      end

      should("render for a title") do
        get(wiki_page_path(id: @wiki_page.title))
        assert_response(:success)
      end

      should("redirect html requests for a nonexistent title") do
        get(wiki_page_path("what"))
        assert_redirected_to(show_or_new_wiki_pages_path(title: "what"))
      end

      should("return 404 to api requests for a nonexistent title") do
        get(wiki_page_path("what"), as: :json)
        assert_response(:not_found)
      end

      should("render for a negated tag") do
        @wiki_page.update_columns(title: "-aaa")
        get(wiki_page_path(id: @wiki_page.id))
        assert_response(:success)
      end
    end

    context("show_or_new action") do
      should("redirect when given a title") do
        get(show_or_new_wiki_pages_path, params: { title: @wiki_page.title })
        assert_redirected_to(@wiki_page)
      end

      should("render when given a nonexistent title") do
        get(show_or_new_wiki_pages_path, params: { title: "what" })
        assert_response :success
      end
    end

    context("new action") do
      should("render") do
        get_auth(new_wiki_page_path, @user, params: { wiki_page: { title: "test" } })
        assert_response(:success)
      end
    end

    context("edit action") do
      should("render") do
        get_auth(wiki_page_path(@wiki_page), @user)
        assert_response :success
      end
    end

    context("create action") do
      should("work") do
        assert_difference("WikiPage.count", 1) do
          post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "abc", body: "abc" }, format: :json })
          assert_response(:success)
        end
        wiki = WikiPage.last
        assert_equal("abc", wiki.title)
      end

      should("not allow an empty body") do
        assert_no_difference("WikiPage.count") do
          post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "abc", body: "" }, format: :json })
          assert_response(:unprocessable_entity)
        end
      end

      should("allow empty body if parent is set") do
        assert_difference("WikiPage.count", 1) do
          post_auth(wiki_pages_path, @privileged, params: { wiki_page: { title: "abc", body: "", parent: @wiki_page.title }, format: :json })
          assert_response(:success)
        end
        wiki = WikiPage.last
        assert_equal("abc", wiki.title)
        assert_equal(@wiki_page.title, wiki.parent)
      end

      should("not create tag") do
        assert_difference({ "WikiPage.count" => 1, "Tag.count" => 0 }) do
          post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "abc", body: "def" }, format: :json })
          assert_response(:success)
        end
        @wiki_page = WikiPage.last
        assert_equal("abc", @wiki_page.title)
        assert_not(Tag.where(name: "abc").exists?)
      end

      context("with prefix") do
        should("work") do
          assert_difference(%w[WikiPage.count Tag.count], 1) do
            post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "character:abc", body: "abc" }, format: :json })
            assert_response(:success)
          end
          @wiki = WikiPage.last
          assert_equal("abc", @wiki.title)
          assert_equal(Tag.categories.character, @wiki.category_id)
        end

        should("not work for disallowed prefixes") do
          assert_no_difference("WikiPage.count") do
            post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "lore:abc", body: "abc" }, format: :json })
            assert_response(:unprocessable_entity)
          end
        end

        should("not work for tags over the threshold") do
          @tag = create(:tag, post_count: 500)
          assert_no_difference("WikiPage.count") do
            post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "character:#{@tag.name}", body: "abc" }, format: :json })
            assert_response(:unprocessable_entity)
          end
        end
      end

      context("with category_id") do
        context("for new tags") do
          should("work") do
            assert_difference(%w[WikiPage.count Tag.count], 1) do
              post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "abc", body: "abc", category_id: Tag.categories.character }, format: :json })
              assert_response(:success)
            end
            @wiki = WikiPage.last
            assert_equal("abc", @wiki.title)
            assert_equal(Tag.categories.character, @wiki.category_id)
          end

          should("not work for disallowed categories") do
            assert_no_difference(%w[WikiPage.count Tag.count]) do
              post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "abc", body: "abc", category_id: Tag.categories.lore }, format: :json })
              assert_response(:unprocessable_entity)
            end
          end

          should("not create wiki pages for tag only changes") do
            assert_difference({ "WikiPage.count" => 0, "Tag.count" => 1 }) do
              post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "abc", category_id: Tag.categories.character }, format: :json })
              assert_response(:success)
            end
            assert_equal(Tag.categories.character, Tag.last.category)
          end
        end

        context("for existing tags") do
          setup do
            @tag = create(:tag, category: Tag.categories.general)
          end

          should("work") do
            assert_difference(%w[WikiPage.count TagTypeVersion.count], 1) do
              post_auth(wiki_pages_path, @user, params: { wiki_page: { title: @tag.name, body: "abc", category_id: Tag.categories.character }, format: :json })
              assert_response(:success)
            end
            assert_equal(@tag.name, WikiPage.last.title)
            assert_equal(Tag.categories.character, @tag.reload.category)
          end

          should("not work for disallowed categories") do
            assert_no_difference(%w[WikiPage.count TagTypeVersion.count]) do
              post_auth(wiki_pages_path, @user, params: { wiki_page: { title: @tag.name, body: "abc", category_id: Tag.categories.lore }, format: :json })
              assert_response(:unprocessable_entity)
            end
            assert_equal(Tag.categories.general, @tag.reload.category)
          end

          should("not create wiki pages for tag only changes") do
            assert_difference({ "WikiPage.count" => 0, "TagTypeVersion.count" => 1 }) do
              post_auth(wiki_pages_path, @user, params: { wiki_page: { title: @tag.name, category_id: Tag.categories.character }, format: :json })
              assert_response(:success)
            end
            assert_equal(Tag.categories.character, @tag.reload.category)
          end

          should("not work for tags over the threshold") do
            @tag.update_columns(post_count: 500)
            assert_no_difference(%w[WikiPage.count TagTypeVersion.count]) do
              post_auth(wiki_pages_path, @user, params: { wiki_page: { title: @tag.name, body: "abc", category_id: Tag.categories.character }, format: :json })
              assert_response(:unprocessable_entity)
            end
            assert_equal(Tag.categories.general, @tag.reload.category)
          end
        end

        context("and prefix") do
          should("prioritize category_id") do
            assert_difference(%w[WikiPage.count Tag.count], 1) do
              post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "character:abc", body: "abc", category_id: Tag.categories.copyright }, format: :json })
              assert_response(:success)
            end
            wiki = WikiPage.last
            assert_equal("abc", wiki.title)
            assert_equal(Tag.categories.copyright, wiki.category_id)
          end

          should("prioritize prefix if category_id is general") do
            assert_difference(%w[WikiPage.count Tag.count], 1) do
              post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "character:abc", body: "abc", category_id: Tag.categories.general }, format: :json })
              assert_response(:success)
            end
            wiki = WikiPage.last
            assert_equal("abc", wiki.title)
            assert_equal(Tag.categories.character, wiki.category_id)
          end
        end

        context("for tag only changes") do
          should("gracefully handle errors") do
            assert_no_difference(%w[WikiPage.count Tag.count]) do
              post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "abc", category_id: 999 }, format: :json })
              assert_response(:unprocessable_entity)
            end
          end

          should("normalize title") do
            assert_difference({ "WikiPage.count" => 0, "Tag.count" => 1 }) do
              post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "character:abc" }, format: :json })
              assert_response(:success)
            end
            tag = Tag.last
            assert_equal("abc", tag.name)
            assert_equal(Tag.categories.character, tag.category)
          end
        end
      end

      context("with category_is_locked") do
        context("for new tags") do
          should("not work for normal users") do
            assert_no_difference(%w[WikiPage.count Tag.count]) do
              post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "abc", body: "abc", category_is_locked: "true" }, format: :json })
              assert_response(:forbidden)
            end
          end

          should("work for admins") do
            assert_difference(%w[WikiPage.count Tag.count], 1) do
              post_auth(wiki_pages_path, @admin, params: { wiki_page: { title: "abc", body: "abc", category_is_locked: "true" }, format: :json })
              assert_response(:success)
            end
            @wiki = WikiPage.last
            assert_equal("abc", @wiki.title)
            assert_equal(true, @wiki.category_is_locked)
          end

          should("not create wiki pages for tag only changes") do
            assert_difference({ "WikiPage.count" => 0, "Tag.count" => 1 }) do
              post_auth(wiki_pages_path, @admin, params: { wiki_page: { title: "abc", category_is_locked: "true" }, format: :json })
              assert_response(:success)
            end
            assert_equal(true, Tag.last.is_locked)
          end
        end

        context("for existing tags") do
          setup do
            @tag = create(:tag, is_locked: false)
          end

          should("not work for normal users") do
            assert_no_difference(%w[WikiPage.count TagTypeVersion.count]) do
              post_auth(wiki_pages_path, @user, params: { wiki_page: { title: @tag.name, body: "abc", category_is_locked: "true" }, format: :json })
              assert_response(:forbidden)
            end
            assert_equal(false, @tag.reload.is_locked)
          end

          should("work for admins") do
            # TODO: tags do not log any change if only is_locked is changed, so we cannot check for that
            # assert_difference(%w[WikiPage.count TagTypeVersion.count], 1) do
            assert_difference("WikiPage.count", 1) do
              post_auth(wiki_pages_path, @admin, params: { wiki_page: { title: @tag.name, body: "abc", category_is_locked: "true" }, format: :json })
              assert_response(:success)
            end
            assert_equal(@tag.name, WikiPage.last.title)
            assert_equal(true, @tag.reload.is_locked)
          end

          should("not create wiki pages for tag only changes") do
            # TODO: tags do not log any change if only is_locked is changed, so we cannot check for that
            # assert_difference({ "WikiPage.count" => 0, "TagTypeVersion.count" => 1 }) do
            assert_no_difference(%w[WikiPage.count]) do
              post_auth(wiki_pages_path, @admin, params: { wiki_page: { title: @tag.name, category_is_locked: "true" }, format: :json })
              assert_response(:success)
            end
            assert_equal(true, @tag.reload.is_locked)
          end
        end
      end
    end

    context("update action") do
      should("work") do
        assert_difference("WikiPageVersion.count", 1) do
          put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { body: "xyz" }, format: :json })
          assert_response(:success)
        end
        assert_equal("xyz", @wiki_page.reload.body)
      end

      should("allow an empty body") do
        assert_difference("WikiPageVersion.count", 1) do
          put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { body: "" }, format: :json })
          assert_response(:success)
        end
        assert_equal("", @wiki_page.reload.body)
      end

      context("with a non-empty tag") do
        setup do
          @tag.update_columns(post_count: 69)
        end

        should("not rename") do
          original_title = @wiki_page.title
          assert_no_difference("WikiPageVersion.count") do
            put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { title: "bar" }, format: :json })
            assert_response(:forbidden)
          end
          assert_equal(original_title, @wiki_page.reload.title)
        end

        should("rename if secondary validations are skipped") do
          assert_difference("WikiPageVersion.count", 1) do
            put_auth(wiki_page_path(@wiki_page), @admin, params: { wiki_page: { title: "bar", skip_secondary_validations: "true" }, format: :json })
            assert_response(:success)
          end
          assert_equal("bar", @wiki_page.reload.title)
        end
      end

      context("with category_id") do
        context("for new tags") do
          setup do
            @wiki_page = as(@user) { create(:wiki_page) }
          end

          context("with body") do
            should("work") do
              assert_difference(%w[WikiPageVersion.count Tag.count]) do
                put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { body: "abc", category_id: Tag.categories.character }, format: :json })
                assert_response(:success)
              end
              assert_equal(Tag.categories.character, @wiki_page.reload.category_id)
            end

            should("not work for disallowed categories") do
              assert_no_difference(%w[WikiPageVersion.count Tag.count]) do
                put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { body: "abc", category_id: Tag.categories.lore }, format: :json })
                assert_response(:unprocessable_entity)
              end
            end
          end

          context("without body") do
            should("work") do
              assert_difference({ "WikiPageVersion.count" => 0, "Tag.count" => 1 }) do
                put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { category_id: Tag.categories.character }, format: :json })
                assert_response(:success)
              end
              assert_equal(Tag.categories.character, @wiki_page.reload.category_id)
            end

            should("not work for disallowed categories") do
              assert_no_difference(%w[WikiPageVersion.count Tag.count]) do
                put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { category_id: Tag.categories.lore }, format: :json })
                assert_response(:unprocessable_entity)
              end
              assert_nil(@wiki_page.category_id)
            end
          end
        end

        context("for existing tags") do
          context("with body") do
            should("work") do
              assert_difference(%w[WikiPageVersion.count TagTypeVersion.count], 1) do
                put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { body: "abc", category_id: Tag.categories.character }, format: :json })
                assert_response(:success)
              end
              assert_equal(@tag.name, WikiPage.last.title)
              assert_equal(Tag.categories.character, @tag.reload.category)
            end

            should("not work for disallowed categories") do
              assert_no_difference(%w[WikiPageVersion.count TagTypeVersion.count]) do
                put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { body: "abc", category_id: Tag.categories.lore }, format: :json })
                assert_response(:unprocessable_entity)
              end
              assert_equal(Tag.categories.general, @tag.reload.category)
            end

            should("not work for tags over the threshold") do
              @tag.update_columns(post_count: 500)
              assert_no_difference(%w[WikiPage.count TagTypeVersion.count]) do
                put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { body: "abc", category_id: Tag.categories.character }, format: :json })
                assert_response(:unprocessable_entity)
              end
              assert_equal(Tag.categories.general, @tag.reload.category)
            end
          end

          context("without body") do
            should("work") do
              assert_difference({ "WikiPageVersion.count" => 0, "TagTypeVersion.count" => 1 }) do
                put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { category_id: Tag.categories.character }, format: :json })
                assert_response(:success)
              end
              assert_equal(@tag.name, WikiPage.last.title)
              assert_equal(Tag.categories.character, @tag.reload.category)
            end

            should("not work for disallowed categories") do
              assert_no_difference(%w[WikiPageVersion.count TagTypeVersion.count]) do
                put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { category_id: Tag.categories.lore }, format: :json })
                assert_response(:unprocessable_entity)
              end
              assert_equal(Tag.categories.general, @tag.reload.category)
            end

            should("not work for tags over the threshold") do
              @tag.update_columns(post_count: 500)
              assert_no_difference(%w[WikiPage.count TagTypeVersion.count]) do
                put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { category_id: Tag.categories.character }, format: :json })
                assert_response(:unprocessable_entity)
              end
              assert_equal(Tag.categories.general, @tag.reload.category)
            end
          end
        end

        context("and prefix") do
          should("prioritize category_id") do
            assert_difference(%w[WikiPageVersion.count TagTypeVersion.count], 1) do
              put_auth(wiki_page_path(@wiki_page), @admin, params: { wiki_page: { title: "character:#{@wiki_page.title}", body: "abc", category_id: Tag.categories.copyright }, format: :json })
              assert_response(:success)
            end
            assert_equal(Tag.categories.copyright, @wiki_page.reload.category_id)
          end

          should("prioritize prefix if category_id is general") do
            assert_difference(%w[WikiPageVersion.count TagTypeVersion.count], 1) do
              put_auth(wiki_page_path(@wiki_page), @admin, params: { wiki_page: { title: "character:#{@wiki_page.title}", body: "abc", category_id: Tag.categories.general }, format: :json })
              assert_response(:success)
            end
            assert_equal(Tag.categories.character, @wiki_page.reload.category_id)
          end

          context("with title change") do
            should("respect title change and prioritize category_id") do
              assert_difference(%w[WikiPageVersion.count Tag.count], 1) do
                put_auth(wiki_page_path(@wiki_page), @admin, params: { wiki_page: { title: "character:abc", body: "abc", category_id: Tag.categories.copyright }, format: :json })
                assert_response(:success)
              end
              @wiki_page.reload
              assert_equal("abc", @wiki_page.title)
              assert_equal(Tag.categories.copyright, @wiki_page.category_id)
            end

            should("respect title change and prioritize prefix if category_id is general") do
              assert_difference(%w[WikiPageVersion.count Tag.count], 1) do
                put_auth(wiki_page_path(@wiki_page), @admin, params: { wiki_page: { title: "character:abc", body: "abc", category_id: Tag.categories.general }, format: :json })
                assert_response(:success)
              end
              @wiki_page.reload
              assert_equal("abc", @wiki_page.title)
              assert_equal(Tag.categories.character, @wiki_page.category_id)
            end

            should("respect title change and prioritize prefix if category_id is unchanged") do
              as(@user) { @tag.update!(category: Tag.categories.copyright) }
              assert_difference(%w[WikiPageVersion.count TagTypeVersion.count], 1) do
                put_auth(wiki_page_path(@wiki_page), @admin, params: { wiki_page: { title: "character:#{@wiki_page.title}", body: "abc", category_id: Tag.categories.copyright }, format: :json })
                assert_response(:success)
              end
              assert_equal(Tag.categories.character, @wiki_page.reload.category_id)
            end
          end
        end
      end

      context("with category_is_locked") do
        context("for new tags") do
          setup do
            @wiki_page = as(@user) { create(:wiki_page) }
          end

          context("with body") do
            should("not work for normal users") do
              assert_no_difference(%w[WikiPageVersion.count Tag.count]) do
                put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { body: "abc", category_is_locked: "true" }, format: :json })
                assert_response(:forbidden)
              end
            end

            should("work for admins") do
              assert_difference(%w[WikiPageVersion.count Tag.count], 1) do
                put_auth(wiki_page_path(@wiki_page), @admin, params: { wiki_page: { body: "abc", category_is_locked: "true" }, format: :json })
                assert_response(:success)
              end
              @wiki = WikiPage.last
              assert_equal("abc", @wiki.body)
              assert_equal(true, @wiki.category_is_locked)
            end
          end

          context("without body") do
            should("not work for normal users") do
              assert_no_difference(%w[WikiPageVersion.count Tag.count]) do
                put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { category_is_locked: "true" }, format: :json })
                assert_response(:forbidden)
              end
            end

            should("work for admins") do
              assert_difference({ "WikiPageVersion.count" => 0, "Tag.count" => 1 }) do
                put_auth(wiki_page_path(@wiki_page), @admin, params: { wiki_page: { category_is_locked: "true" }, format: :json })
                assert_response(:success)
              end
              @wiki = WikiPage.last
              assert_equal(true, @wiki.category_is_locked)
            end
          end
        end

        context("for existing tags") do
          context("with body") do
            should("not work for normal users") do
              assert_no_difference(%w[WikiPageVersion.count TagTypeVersion.count]) do
                put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { body: "abc", category_is_locked: "true" }, format: :json })
                assert_response(:forbidden)
              end
              assert_equal(false, @tag.reload.is_locked)
            end

            should("work for admins") do
              # TODO: tags do not log any change if only is_locked is changed, so we cannot check for that
              # assert_difference(%w[WikiPageVersion.count TagTypeVersion.count], 1) do
              assert_difference("WikiPageVersion.count", 1) do
                put_auth(wiki_page_path(@wiki_page), @admin, params: { wiki_page: { body: "abc", category_is_locked: "true" }, format: :json })
                assert_response(:success)
              end
              assert_equal("abc", @wiki_page.reload.body)
              assert_equal(true, @tag.reload.is_locked)
            end
          end

          context("without body") do
            should("not work for normal users") do
              assert_no_difference(%w[WikiPageVersion.count TagTypeVersion.count]) do
                put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { category_is_locked: "true" }, format: :json })
                assert_response(:forbidden)
              end
              assert_equal(false, @tag.reload.is_locked)
            end

            should("work for admins") do
              # TODO: tags do not log any change if only is_locked is changed, so we cannot check for that
              # assert_difference({ "WikiPageVersion.count" => 0, "TagTypeVersion.count" => 1 }) do
              assert_no_difference("WikiPageVersion.count") do
                put_auth(wiki_page_path(@wiki_page), @admin, params: { wiki_page: { category_is_locked: "true" }, format: :json })
                assert_response(:success)
              end
              assert_equal(true, @tag.reload.is_locked)
            end
          end
        end
      end
    end

    context("destroy action") do
      should("work") do
        assert_difference("WikiPage.count", -1) do
          delete_auth(wiki_page_path(@wiki_page), @admin, params: { format: :json })
          assert_response(:success)
        end
        assert_not(WikiPage.exists?(@wiki_page.id))
      end
    end

    context("revert action") do
      setup do
        as(@user) do
          @wiki_page = create(:wiki_page, body: "1")
          travel_to(1.day.from_now) do
            @wiki_page.update(body: "1 2")
          end
          travel_to(2.days.from_now) do
            @wiki_page.update(body: "1 2 3")
          end
        end
      end

      should("revert to a previous version") do
        version = @wiki_page.versions.first
        assert_equal("1", version.body)
        assert_difference("WikiPageVersion.count", 1) do
          put_auth(revert_wiki_page_path(@wiki_page), @user, params: { version_id: version.id, format: :json })
          assert_response(:success)
        end
        assert_equal("1", @wiki_page.reload.body)
      end

      should("not allow reverting to a previous version of another wiki page") do
        @wiki_page_2 = as(@user) { create(:wiki_page) }

        assert_no_difference("WikiPageVersion.count") do
          put_auth(revert_wiki_page_path(@wiki_page), @user, params: { version_id: @wiki_page_2.versions.first.id, format: :json })
          assert_response(:missing)
        end
        assert_not_equal(@wiki_page.reload.body, @wiki_page_2.reload.body)
      end
    end
  end
end
