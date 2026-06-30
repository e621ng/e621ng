import TextUtils from "@/utility/TextUtils";
import Toast from "@/utility/Toast";

$(() => {
  const button = $("#copy-tag");
  if (!button.length) return;

  if (!TextUtils.clipboardSupported) return;
  button.show();

  button.on("click.copyTag", (event: JQuery.ClickEvent<HTMLButtonElement>) => {
    event.preventDefault();
    event.stopImmediatePropagation();
    const tag = button.data("clipboard-text");
    TextUtils.copyToClipboard(tag)
      .then(() => Toast.create("Copied to clipboard!", { timeout: 1 }))
      .catch(() => Toast.alert("Failed to copy tag to clipboard."));
  });
});
