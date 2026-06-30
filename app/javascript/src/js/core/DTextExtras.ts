import SVGIcon from "@/utility/SVGIcon";
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
  const button = $("<button>")
    .addClass("copy-code")
    .attr({
      "type": "button",
      "title": "Copy code to clipboard",
    })
    .append(SVGIcon.render("copy"))
    .prependTo(wrapper);

  button.on("click", () => {
    const code = wrapper.clone().children("button.copy-code").remove().end().text();
    TextUtils.copyToClipboard(code)
      .then(() => Toast.create("Copied to clipboard!", { timeout: 1 }))
      .catch(() => Toast.alert("Failed to copy code to clipboard."));
  });
}
