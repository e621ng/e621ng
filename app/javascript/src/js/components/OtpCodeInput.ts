type Mode = "totp" | "backup";

const TOTP_LENGTH = 6;
const TOTP_SHAPED = /^\d{1,6}$/;

/**
 * Enhances the dual-purpose OTP field with six visual TOTP cells and a separate
 * backup-code input. Separate elements are intentional because password managers
 * don't reliably re-evaluate autocomplete/data-bwignore when one input changes mode.
 * Only the enabled input submits as totp[code].
 */
export default class OtpCodeInput {

  // Delay between cells during a bulk-fill reveal.
  private static readonly REVEAL_STEP_MS = 90;

  private wrapper: HTMLElement;
  private totpInput: HTMLInputElement;
  private backupInput: HTMLInputElement;
  private cells: HTMLElement[];
  private labelElement: HTMLLabelElement;
  private toggle: HTMLButtonElement;

  private mode: Mode = "totp";
  private errorElement: HTMLElement | null = null;
  private errorShakeTimer?: number;

  private previousValue = "";

  // Invalidates callbacks belonging to a superseded reveal.
  private revealGeneration = 0;

  // Bitwarden can emit both input and change for the same autofill.
  private revealValue: string | null = null;

  constructor (wrapper: JQuery<HTMLElement>) {
    const root = wrapper[0];
    if (!root || root.dataset.otpInitialized === "true") return;

    const box = root.querySelector<HTMLElement>(".otp-code-input-box");
    const labelElement = root.querySelector<HTMLLabelElement>(".otp-code-input-label");
    const field = root.querySelector<HTMLElement>(".otp-code-input-field");
    const totpInput = root.querySelector<HTMLInputElement>(".otp-code-input-real");
    const cells = Array.from(root.querySelectorAll<HTMLElement>(".otp-code-input-cell"));
    const toggle = root.querySelector<HTMLButtonElement>(".otp-code-input-toggle");
    const { labelTotp, labelBackup, toggleToBackup, toggleToTotp } = root.dataset;

    // Bail out before mutating the DOM if the component markup is incomplete.
    if (
      !box
      || !labelElement
      || !field
      || !totpInput
      || !toggle
      || cells.length !== TOTP_LENGTH
      || !labelTotp
      || !labelBackup
      || !toggleToBackup
      || !toggleToTotp
    ) return;

    this.wrapper = root;
    this.labelElement = labelElement;
    this.totpInput = totpInput;
    this.cells = cells;
    this.toggle = toggle;

    this.backupInput = this.createBackupInput();

    const raw = totpInput.value;
    const normalized = raw.replace(/[\s-]/g, "");
    const startMode: Mode = raw === "" || TOTP_SHAPED.test(normalized) ? "totp" : "backup";
    const wasAutofocused = totpInput.hasAttribute("autofocus");

    field.appendChild(this.backupInput);

    if (startMode === "backup") {
      this.backupInput.value = raw;
      totpInput.value = "";
    } else {
      this.sanitize();
    }

    this.applyMode(startMode);
    this.render();
    this.previousValue = this.totpInput.value;
    this.wrapper.classList.add("is-enhanced");

    if (startMode === "backup" && wasAutofocused) {
      this.backupInput.focus();
      const end = this.backupInput.value.length;
      this.backupInput.setSelectionRange(end, end);
    }

    this.totpInput.addEventListener("paste", (event) => this.handlePaste(event));
    this.totpInput.addEventListener("beforeinput", (event) => this.handleBeforeInput(event as InputEvent));
    this.totpInput.addEventListener("input", () => this.handleValueChange());
    this.totpInput.addEventListener("change", () => this.handleValueChange());
    this.totpInput.addEventListener("focus", () => this.render());
    this.totpInput.addEventListener("blur", () => this.render());
    this.totpInput.addEventListener("keyup", () => this.render());
    this.totpInput.addEventListener("select", () => this.render());
    this.totpInput.addEventListener("click", (event) => this.handleClick(event));
    this.toggle.addEventListener("click", () => this.switchMode(this.mode === "totp" ? "backup" : "totp"));

    this.cells.forEach((cell) => {
      cell.addEventListener("animationend", (event) => {
        if (event.animationName === "otp-cell-pop") {
          cell.classList.remove("digit-pop");
        }
      });
    });

    root.dataset.otpInitialized = "true";

    const form = root.closest("form");
    if (form) form.addEventListener("submit", (event) => this.handleSubmit(event));

    this.errorElement = form?.querySelector<HTMLElement>("#auth-error") ?? null;
    this.observeAuthError();
  }

  private handleSubmit (event: Event) {
    if (this.mode !== "backup") return;

    const normalized = this.backupInput.value.replace(/[\s-]/g, "");
    if (!/^\d{6}$/.test(normalized)) return;

    event.preventDefault();
    event.stopImmediatePropagation();
    this.showError("Verification code was incorrect.");
    this.backupInput.focus();
  }

  private showError (message: string) {
    if (this.errorElement) this.errorElement.textContent = message;
  }

  private createBackupInput (): HTMLInputElement {
    const input = document.createElement("input");
    const describedBy = this.totpInput.getAttribute("aria-describedby");
    if (describedBy) input.setAttribute("aria-describedby", describedBy);
    input.type = "text";
    input.id = "totp_backup_code";
    input.name = "totp[code]";
    input.className = "otp-code-input-backup";
    input.autocomplete = "off";
    input.setAttribute("data-bwignore", "1");
    input.required = true;
    input.setAttribute("autocapitalize", "none");
    input.spellcheck = false;
    input.setAttribute("autocorrect", "off");
    input.disabled = true;
    return input;
  }

  private handleValueChange () {
    if (this.mode === "totp") this.sanitize();

    const value = this.totpInput.value;

    if (this.mode === "totp" && this.revealValue !== null && this.revealValue === value) {
      // Ignore Bitwarden's duplicate change event for an autofill already being revealed.
      this.previousValue = value;
      return;
    }

    const previousValue = this.previousValue;
    this.previousValue = value;
    this.renderValueChange(previousValue, value);
  }

  private prefersReducedMotion (): boolean {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  private renderValueChange (previousValue: string, value: string) {
    const changedCells = this.cells.filter((_, index) => previousValue[index] !== value[index]);
    const isDeletion = value.length < previousValue.length;
    const reducedMotion = this.prefersReducedMotion();

    if (
      !isDeletion
      && changedCells.length > 1
      && value.length === TOTP_LENGTH
      && !reducedMotion
    ) {
      this.startBulkReveal(value);
      return;
    }

    this.cancelRevealAndRender();

    if (isDeletion || reducedMotion) return;

    changedCells.forEach((cell) => this.restartCellPop(cell));
  }

  // The real input is complete immediately; only the visual cells are staggered.
  private startBulkReveal (value: string) {
    this.cancelReveal();
    this.revealValue = value;
    const generation = this.revealGeneration;

    this.cells.forEach((cell) => {
      cell.textContent = "";
      cell.classList.remove("active", "empty", "occupied");
    });

    value.split("").forEach((char, index) => {
      window.setTimeout(() => {
        if (generation !== this.revealGeneration) return;

        const cell = this.cells[index];
        cell.textContent = char;
        this.restartCellPop(cell);

        if (index === value.length - 1) {
          this.revealValue = null;
          this.render();
        }
      }, index * OtpCodeInput.REVEAL_STEP_MS);
    });
  }

  private restartCellPop (cell: HTMLElement) {
    cell.classList.remove("digit-pop");
    void cell.offsetWidth;
    cell.classList.add("digit-pop");
  }

  private cancelReveal () {
    this.revealGeneration++;
    this.revealValue = null;
    this.cells.forEach((cell) => cell.classList.remove("digit-pop"));
  }

  private cancelRevealAndRender () {
    this.cancelReveal();
    this.render();
  }

  private handlePaste (event: ClipboardEvent) {
    if (this.mode !== "totp") return;

    const pasted = event.clipboardData?.getData("text") ?? "";
    const code = pasted.replace(/\D/g, "");

    if (code.length !== TOTP_LENGTH) return;

    event.preventDefault();

    const previousValue = this.totpInput.value;
    this.totpInput.value = code;
    this.totpInput.setSelectionRange(TOTP_LENGTH, TOTP_LENGTH);
    this.previousValue = code;
    this.renderValueChange(previousValue, code);
  }

  // Overwrite an occupied TOTP slot instead of inserting and shifting later digits.
  private handleBeforeInput (event: InputEvent) {
    if (this.mode !== "totp") return;
    if (event.inputType !== "insertText") return;
    const data = event.data;
    if (!data || data.length !== 1 || !/^[0-9]$/.test(data)) return;
    if (this.totpInput.selectionStart !== this.totpInput.selectionEnd) return;
    const start = this.totpInput.selectionStart ?? 0;
    const value = this.totpInput.value;

    // A caret at boundary 6 on a full code targets the last visible slot.
    const target = value.length === TOTP_LENGTH && start === TOTP_LENGTH ? TOTP_LENGTH - 1 : start;

    if (target >= value.length) return; // genuinely at/after the end with room to grow — normal append; sanitizer clamps to 6 as before

    event.preventDefault();

    const nextValue = value.slice(0, target) + data + value.slice(target + 1);
    this.totpInput.value = nextValue;
    this.totpInput.setSelectionRange(target + 1, target + 1);
    this.previousValue = nextValue;
    this.renderValueChange(value, nextValue);
  }

  // Strip non-digits and clamp to six while preserving the selection.
  private sanitize () {
    const raw = this.totpInput.value;
    const rawStart = this.totpInput.selectionStart ?? raw.length;
    const rawEnd = this.totpInput.selectionEnd ?? raw.length;

    const adjust = (boundary: number) => Math.min(raw.slice(0, boundary).replace(/\D/g, "").length, TOTP_LENGTH);

    const sanitized = raw.replace(/\D/g, "").slice(0, TOTP_LENGTH);
    const start = adjust(rawStart);
    const end = adjust(rawEnd);

    if (sanitized !== raw) this.totpInput.value = sanitized;
    this.totpInput.setSelectionRange(start, end);
  }

  private render () {
    if (this.mode !== "totp") return;

    const value = this.totpInput.value;

    // Don't overwrite cells while a reveal for this value owns the presentation.
    if (this.revealValue !== null && this.revealValue === value) return;

    const focused = document.activeElement === this.totpInput;
    const activeBoundary = this.totpInput.selectionStart ?? 0;
    const activeCell = Math.min(activeBoundary, this.cells.length - 1);

    this.cells.forEach((cell, index) => {
      const char = value[index] ?? "";
      cell.textContent = char;
      const isActive = focused && index === activeCell;
      cell.classList.toggle("active", isActive);
      // CSS picks the caret shape from these: a centered pipe in an empty
      // slot, an underscore beneath the glyph in an occupied one.
      cell.classList.toggle("empty", isActive && char === "");
      cell.classList.toggle("occupied", isActive && char !== "");
    });
  }

  // Map clicks to the nearest visual slot rather than the hidden input's text metrics.
  private handleClick (event: MouseEvent) {
    if (this.mode !== "totp" || this.cells.length === 0) return;

    const rects = this.cells.map((cell) => cell.getBoundingClientRect());
    let index = rects.findIndex((rect) => event.clientX >= rect.left && event.clientX < rect.right);
    if (index === -1) {
      // Clicked a gap/padding pixel between cells: fall back to nearest center.
      let nearestDistance = Infinity;
      rects.forEach((rect, i) => {
        const distance = Math.abs(event.clientX - (rect.left + (rect.width / 2)));
        if (distance < nearestDistance) {
          nearestDistance = distance;
          index = i;
        }
      });
    }

    const caret = Math.min(index, this.totpInput.value.length);
    this.totpInput.setSelectionRange(caret, caret);
    this.render();
  }

  private applyMode (mode: Mode) {
    this.mode = mode;
    this.wrapper.dataset.mode = mode;

    const active = mode === "totp" ? this.totpInput : this.backupInput;
    const inactive = mode === "totp" ? this.backupInput : this.totpInput;
    active.disabled = false;
    inactive.disabled = true;

    this.labelElement.htmlFor = active.id;

    if (mode === "totp") {
      // No maxlength: the browser would apply it to a raw paste before the
      // sanitizer ever sees it (e.g. "123 456" -> truncated to "123 45" -> only
      // "12345" survives sanitization). The sanitizer alone clamps to 6 digits.
      this.totpInput.setAttribute("inputmode", "numeric");
      this.totpInput.setAttribute("pattern", "[0-9]{6}");
      this.labelElement.textContent = this.wrapper.dataset.labelTotp!;
      this.toggle.textContent = this.wrapper.dataset.toggleToBackup!;
    } else {
      this.labelElement.textContent = this.wrapper.dataset.labelBackup!;
      this.toggle.textContent = this.wrapper.dataset.toggleToTotp!;
    }
  }

  private switchMode (mode: Mode) {
    this.cancelReveal();
    this.totpInput.value = "";
    this.backupInput.value = "";
    this.previousValue = "";
    this.applyMode(mode);
    this.render();
    const active = mode === "totp" ? this.totpInput : this.backupInput;
    active.focus();
    active.setSelectionRange(0, 0);
  }

  // Handles both server-rendered errors and errors injected later by AuthOverlay.
  private observeAuthError () {
    const errorEl = this.errorElement;
    if (!errorEl) return;

    const trigger = () => {
      if (errorEl.textContent?.trim()) this.triggerErrorFeedback();
    };

    new MutationObserver(trigger).observe(errorEl, { childList: true, characterData: true, subtree: true });
    trigger(); // Handle an error already rendered with the page.
  }

  private triggerErrorFeedback () {
    window.clearTimeout(this.errorShakeTimer);

    // Restart the shake if an earlier one is still running.
    this.wrapper.classList.remove("otp-code-input-error");
    void this.wrapper.offsetWidth;
    this.wrapper.classList.add("otp-code-input-error");
    this.errorShakeTimer = window.setTimeout(() => {
      this.wrapper.classList.remove("otp-code-input-error");
    }, 2000);
  }
}
