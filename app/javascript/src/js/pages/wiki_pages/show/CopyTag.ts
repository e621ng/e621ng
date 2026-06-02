import Toast from "@/utility/Toast";

$(() => {
  const button = $("#copy-tag");
  if (!button.length) return;

  if (!navigator.clipboard) {
    button.remove();
    return; // Clipboard API not supported
  }

  button.on("click.copyTag", (event: JQuery.ClickEvent<HTMLButtonElement>) => {
    event.preventDefault();
    event.stopImmediatePropagation();
    const tag = button.data("clipboard-text");
    try {
      navigator.clipboard.writeText(tag)
        .then(() => Toast.create("Copied to clipboard!", { timeout: 1 }))
        .catch(() => Toast.alert("Failed to copy tag to clipboard."));
    } catch { Toast.alert("Failed to copy tag to clipboard."); }
  });
});
