import TextUtils from "@/utility/TextUtils";
import Toast from "@/utility/Toast";

$(() => {
  // Prevent link navigation on first tap of a spoiler tag on touch devices.
  $(document).on("touchend.danbooru", ".spoiler", function (e) {
    if ($(e.target).closest("a", this).length && !$(this).hasClass("spoiler-revealed")) {
      e.preventDefault();
    }
    $(this).addClass("spoiler-revealed");
  });

  $(document).on("touchstart.danbooru", function (e) {
    if (!$(e.target).closest(".spoiler").length) {
      $(".spoiler.spoiler-revealed").removeClass("spoiler-revealed");
    }
  });

  // Copy <pre> content to clipboard on click.
  if (TextUtils.clipboardSupported) {
    $(".dtext-container pre").each((_index, element) => bootstrapCodeBlocks($(element)));
  }
});

function bootstrapCodeBlocks (wrapper: JQuery<HTMLElement>) {
  const button = $("<button class='copy-code' type='button'>copy</button>")
    .prependTo(wrapper);
  button.on("click", () => {
    const code = wrapper.text().replace(/^copy/, "");
    try {
      TextUtils.copyToClipboard(code);
      Toast.create("Copied to clipboard!", { timeout: 1 });
    } catch {
      Toast.alert("Failed to copy code to clipboard.");
    }
  });
}
