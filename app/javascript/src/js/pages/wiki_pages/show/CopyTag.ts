import Toast from "@/utility/Toast";

$(() => {
  console.log("Initializing wiki page tag copy button...");

  const button = $("#copy-tag");
  if (!button.length) return;

  if (typeof navigator.clipboard !== "object") {
    button.remove();
    return; // Clipboard API not supported
  }

  button.on("click.copyTag", (event: JQuery.ClickEvent<HTMLButtonElement>) => {
    event.preventDefault();
    event.stopImmediatePropagation();
    const tag = button.data("clipboard-text");
    try {
      navigator.clipboard.writeText(tag)
        .then(() => Toast.create("Copied to clipboard!", { timeout: 1 }));
    } catch { Toast.alert("Failed to copy tag to clipboard."); }
  });
});
