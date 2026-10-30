import State from "@/utility/StateUtils";
import SVGIcon from "@/utility/SVGIcon";
import TextUtils from "@/utility/TextUtils";
import ToastManager from "@/utility/Toast";

type ClickListener = (event: MouseEvent) => void;

// Module re-imports (specs) must replace the listener, not stack a second one
const LISTENER_KEY = Symbol.for("e621.copybutton.listener");

/**
 * Shared "copy to clipboard" button.
 * Server-rendered buttons (IconHelper#copy_button) carry their text in `data-copy-text`
 * and are handled by a single delegated listener; JS-built buttons come from `create()`.
 * Buttons stay hidden by CSS unless `html.clipboard-supported` is set.
 */
export default class CopyButton {

  public static get supported (): boolean {
    return TextUtils.clipboardSupported;
  }

  /**
   * Copies the text and reports the outcome with a toast.
   * @param text Text to copy
   * @param label What is being copied, used in the failure message
   * @returns True if the text was copied
   */
  public static async copy (text: string, label = "text"): Promise<boolean> {
    try {
      await TextUtils.copyToClipboard(text);
      ToastManager.create("Copied to clipboard!", { timeout: 1 });
      return true;
    } catch {
      ToastManager.alert(`Failed to copy ${label} to clipboard.`);
      return false;
    }
  }

  /**
   * Builds a copy button for client-rendered content.
   * @param label What is being copied, used in the title and failure message
   * @param text Resolves the text to copy at click time
   */
  public static create ({ label, text }: { label: string; text: () => string }): HTMLButtonElement {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "copy-button";
    button.title = `Copy ${label} to clipboard`;

    const icon = SVGIcon.render("copy");
    if (icon) button.append(icon);

    button.addEventListener("click", (event) => {
      event.preventDefault();
      CopyButton.copy(text(), label);
    });
    return button;
  }

  public static bootstrap (): void {
    document.documentElement.classList.toggle("clipboard-supported", CopyButton.supported);

    const listener: ClickListener = (event) => {
      const button = (event.target as Element | null)?.closest<HTMLButtonElement>("button.copy-button[data-copy-text]");
      if (!button) return;

      event.preventDefault();
      CopyButton.copy(button.dataset.copyText ?? "", button.dataset.copyLabel);
    };

    const host = window as unknown as Record<symbol, ClickListener | undefined>;
    const previous = host[LISTENER_KEY];
    if (previous) document.removeEventListener("click", previous);
    host[LISTENER_KEY] = listener;
    document.addEventListener("click", listener);
  }
}

State.onReady(() => CopyButton.bootstrap());
