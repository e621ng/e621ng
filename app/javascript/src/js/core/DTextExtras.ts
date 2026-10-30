import CopyButton from "@/core/CopyButton";
import State from "@/utility/StateUtils";

State.onReady(() => {
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
  if (CopyButton.supported) {
    for (const pre of document.querySelectorAll<HTMLElement>(".dtext-container pre"))
      bootstrapCodeBlock(pre);
  }
});

function bootstrapCodeBlock (pre: HTMLElement) {
  pre.prepend(CopyButton.create({ label: "code", text: () => codeText(pre) }));
}

function codeText (pre: HTMLElement): string {
  const clone = pre.cloneNode(true) as HTMLElement;
  clone.querySelectorAll(".copy-button").forEach((button) => button.remove());
  return clone.textContent ?? "";
}
