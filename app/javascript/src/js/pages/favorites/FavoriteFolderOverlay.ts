import ImmersiveInput from "@/components/ImmersiveInput";
import FavoriteFolder from "@/models/FavoriteFolder";

/**
 * Centered modal for creating/renaming a Favorites folder, reusing AuthOverlay's shared
 * box-shape classes (see common/overlay_modal.scss) without depending on AuthOverlay
 * itself. The heading lives inside form.simple_form (the themed panel), not the wrapper
 * (positioning only) - see the DOM built below.
 */
export default class FavoriteFolderOverlay {
  private backdrop: HTMLDivElement;
  private closeButton: HTMLButtonElement;
  private heading: HTMLHeadingElement;
  private form: HTMLFormElement;
  private nameInput: HTMLInputElement;
  private errorEl: HTMLDivElement;
  private submitButton: HTMLButtonElement;

  private folderId: string | number | null = null;
  private parentId: string | number | null = null;
  private submitting = false;
  private trigger: HTMLElement | null = null;

  constructor () {
    this.backdrop = document.createElement("div");
    this.backdrop.className = "st-overlay hidden";
    this.backdrop.setAttribute("role", "dialog");
    this.backdrop.setAttribute("aria-modal", "true");
    this.backdrop.tabIndex = -1;
    this.backdrop.addEventListener("mousedown", (event) => {
      if (event.target !== this.backdrop) return;
      this.close();
    });
    this.backdrop.addEventListener("keydown", (event) => {
      if (event.key !== "Escape") return;
      this.close();
    });

    const wrapper = document.createElement("div");
    wrapper.className = "st-overlay-wrapper favorite-folder-overlay-wrapper";
    this.backdrop.appendChild(wrapper);

    this.closeButton = document.createElement("button");
    this.closeButton.type = "button";
    this.closeButton.className = "st-button close-button";
    this.closeButton.innerHTML = "&times;";
    this.closeButton.setAttribute("aria-label", "Close");
    this.closeButton.addEventListener("click", () => this.close());

    this.heading = document.createElement("h1");
    this.heading.id = "favorite-folder-overlay-title";
    this.backdrop.setAttribute("aria-labelledby", this.heading.id);

    this.form = document.createElement("form");
    this.form.className = "simple_form";
    this.form.addEventListener("submit", this.onSubmit);

    const inputWrapper = document.createElement("label");
    inputWrapper.className = "st-immersive-input";
    const labelText = document.createElement("span");
    labelText.className = "label-text";
    labelText.textContent = "Folder Name";
    this.nameInput = document.createElement("input");
    this.nameInput.type = "text";
    this.nameInput.required = true;
    this.nameInput.maxLength = 100;
    inputWrapper.append(labelText, this.nameInput);

    this.submitButton = document.createElement("button");
    this.submitButton.type = "submit";
    this.submitButton.className = "st-button submit";
    this.submitButton.textContent = "Save";

    this.errorEl = document.createElement("div");
    this.errorEl.className = "st-overlay-error";

    this.form.append(this.heading, inputWrapper, this.submitButton, this.errorEl);
    wrapper.append(this.closeButton, this.form);
    document.body.appendChild(this.backdrop);

    new ImmersiveInput($(this.nameInput) as JQuery<HTMLInputElement>);
  }

  openForCreate (parentId: string | number | null, trigger: HTMLElement): void {
    if (this.submitting) return; // a pending request owns the current form state
    this.folderId = null;
    this.parentId = parentId;
    this.heading.textContent = "New Folder";
    this.nameInput.value = "";
    this.show(trigger);
  }

  openForRename (folderId: string | number, name: string, trigger: HTMLElement): void {
    if (this.submitting) return;
    this.folderId = folderId;
    this.parentId = null;
    this.heading.textContent = "Rename Folder";
    this.nameInput.value = name;
    this.show(trigger, true);
  }

  close (): void {
    if (this.submitting) return; // ignore Escape/backdrop/X while a request is in flight
    if (this.backdrop.classList.contains("hidden")) return;
    this.backdrop.classList.add("hidden");
    this.trigger?.focus();
  }

  private show (trigger: HTMLElement, selectName = false): void {
    this.trigger = trigger;
    this.submitting = false;
    this.submitButton.disabled = false;
    this.closeButton.disabled = false;
    this.setError("");
    this.backdrop.classList.remove("hidden");

    // ImmersiveInput's floating-label state only updates on focus/blur/input, not a
    // direct .value assignment (rename's pre-filled name).
    this.nameInput.dispatchEvent(new Event("input", { bubbles: true }));
    this.nameInput.focus();
    if (selectName) this.nameInput.select();
  }

  private setError (message: string): void {
    this.errorEl.textContent = message;
  }

  private onSubmit = (event: SubmitEvent): void => {
    event.preventDefault();
    if (this.submitting) return;

    const name = this.nameInput.value.trim();
    if (!name) {
      this.setError("Folder name is required.");
      this.nameInput.focus();
      return;
    }

    this.submitting = true;
    this.submitButton.disabled = true;
    this.closeButton.disabled = true;
    this.setError("");

    const request = this.folderId
      ? FavoriteFolder.rename(this.folderId, name)
      : FavoriteFolder.create(name, this.parentId);

    request.then(() => {
      window.location.reload();
    }).catch((error: Error) => {
      this.submitting = false;
      this.submitButton.disabled = false;
      this.closeButton.disabled = false;
      this.setError(error.message || "Something went wrong.");
    });
  };
}

$(() => {
  const trigger = document.getElementById("favorite-folder-new-trigger");
  if (!trigger) return; // not on a folder-scoped Favorites page

  const overlay = new FavoriteFolderOverlay();

  trigger.addEventListener("click", (event) => {
    event.preventDefault();
    overlay.openForCreate(trigger.dataset.parentId || null, trigger);
  });

  // Delegated: rename triggers live inside FolderCardComponent, one per card.
  document.addEventListener("click", (event) => {
    const renameTrigger = (event.target as Element).closest<HTMLElement>(".favorite-folder-rename-trigger");
    if (!renameTrigger) return;
    event.preventDefault();
    overlay.openForRename(renameTrigger.dataset.folderId || "", renameTrigger.dataset.folderName || "", renameTrigger);
  });
});
