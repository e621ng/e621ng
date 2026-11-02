# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Content Security Policy" do
  subject(:script_src) do
    get furid_path
    script_src_of(response)
  end

  def script_src_of(response)
    header = response.headers["Content-Security-Policy"]
    header.split(";").map(&:strip).find { |directive| directive.start_with?("script-src ") }
  end

  it "sends a Content-Security-Policy header" do
    get furid_path
    expect(response.headers["Content-Security-Policy"]).to be_present
  end

  it "includes 'strict-dynamic' in script-src so the host allowlist is ignored by CSP3 browsers" do
    expect(script_src).to include("'strict-dynamic'")
  end

  it "includes a per-request nonce in script-src" do
    expect(script_src).to match(/'nonce-[^']+'/)
  end

  it "does not allow WebAssembly outside of Flash post pages" do
    expect(script_src).not_to include("'wasm-unsafe-eval'")
  end

  # Ruffle, the Flash emulator, needs to compile WebAssembly, and only on the pages that render its player.
  describe "on post pages" do
    include_context "as admin"

    let(:flash_post) { create(:post, file_ext: "swf", rating: "s") }

    def expect_wasm_allowed(response)
      directive = script_src_of(response)
      expect(directive).to include("'wasm-unsafe-eval'", "'strict-dynamic'")
      expect(directive).to match(/'nonce-[^']+'/)
      expect(directive).not_to include("'unsafe-inline'", "blob:")
      expect(response.headers["Content-Security-Policy"]).not_to include("worker-src")
      expect(response.headers["Content-Security-Policy"]).to include("child-src 'none'")
    end

    def expect_wasm_withheld(response)
      expect(script_src_of(response)).not_to include("'wasm-unsafe-eval'")
    end

    it "allows WebAssembly on a Flash post" do
      get post_path(flash_post)
      expect_wasm_allowed(response)
    end

    it "allows WebAssembly on a Flash post's show_seq page" do
      get show_seq_post_path(flash_post)
      expect_wasm_allowed(response)
    end

    it "does not allow WebAssembly on an image post" do
      get post_path(create(:post))
      expect_wasm_withheld(response)
    end

    context "when a Flash post is withheld" do
      let(:explicit_post) { create(:post, file_ext: "swf", rating: "e") }

      it "does not allow WebAssembly when the site is in safe mode" do
        allow(Danbooru.config.custom_configuration).to receive(:safe_mode?).and_return(true)
        get post_path(explicit_post)
        expect_wasm_withheld(response)
      end

      it "does not allow WebAssembly when safe mode is requested" do
        get post_path(explicit_post), params: { safe_mode: "1" }
        expect_wasm_withheld(response)
      end

      it "does not allow WebAssembly when the user has safe mode enabled" do
        user = create(:user, enable_safe_mode: true)
        sign_in_as user
        # sign_in_as replaces SessionLoader#load, which is what turns the user's setting into CurrentUser.safe_mode.
        allow(SessionLoader.new(nil)).to receive(:load) do
          CurrentUser.user = user
          CurrentUser.ip_addr = "127.0.0.1"
          CurrentUser.safe_mode = user.enable_safe_mode?
        end
        get post_path(explicit_post)
        expect_wasm_withheld(response)
      end

      it "does not allow WebAssembly when the post is hidden from anonymous users" do
        get post_path(create(:post, file_ext: "swf", hide_from_anonymous: true))
        expect_wasm_withheld(response)
      end

      it "does not allow WebAssembly on a deleted post for anonymous users or members" do
        deleted_post = create(:deleted_post, file_ext: "swf")
        get post_path(deleted_post)
        expect_wasm_withheld(response)

        sign_in_as create(:user)
        get post_path(deleted_post)
        expect_wasm_withheld(response)
      end
    end

    it "allows WebAssembly on a deleted Flash post for staff, who can see it" do
      sign_in_as create(:janitor_user)
      get post_path(create(:deleted_post, file_ext: "swf"))
      expect_wasm_allowed(response)
    end
  end
end
