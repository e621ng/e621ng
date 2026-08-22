type Mode = "totp" | "backup";

const TOTP_LENGTH = 6;
const TOTP_SHAPED = /^\d+$/;

interface TotpInputSnapshot {
  value: string;
  disabled: boolean;
  hidden: HTMLElement["hidden"];
  autocomplete: string | null;
  inputmode: string | null;
  pattern: string | null;
  labelFor: string;
  labelText: string | null;
}

function restoreAttribute (el: HTMLElement, name: string, value: string | null) {
  if (value === null) el.removeAttribute(name);
  else el.setAttribute(name, value);
}

/**
 * Enhances a single dual-purpose TOTP/backup-code text field with a six-cell
 * authenticator-code presentation and a mode switch to a dedicated backup-code field.
 *
 * The six cells are aria-hidden and purely presentational. Once enhanced, the
 * original server-rendered input becomes the dedicated TOTP control and a second,
 * JS-created input becomes the dedicated backup-code control — password managers
 * (Bitwarden in particular) key off `data-bwignore`/`autocomplete` per element and
 * don't reliably notice those being changed on a single reused element, so the two
 * modes get genuinely separate elements instead. Only one is ever enabled at a
 * time, so only one submits as `totp[code]` regardless of which mode is active.
 *
 * `inputmode`/`pattern` are applied here, at runtime, rather than being
 * server-rendered, so a JS failure leaves the field exactly as capable as it is
 * today (plain text, no restrictions, works for either code type). Length is
 * enforced only by the sanitizer, not `maxlength`, so a raw browser paste is never
 * truncated ahead of it.
 */
export default class OtpCodeInput {

  // Delay between each cell's reveal during a bulk-fill (autofill/paste)
  // animation — see handleValueChange()/startBulkReveal().
  private static readonly REVEAL_STEP_MS = 90;

  private wrapper: HTMLElement;
  private totpInput: HTMLInputElement;
  private backupInput: HTMLInputElement;
  private cells: HTMLElement[];
  private labelElement: HTMLLabelElement;
  private toggle: HTMLButtonElement;

  private mode: Mode = "totp";
  private errorElement: HTMLElement | null = null;
  private errorDismissTimer?: number;
  private errorShakeTimer?: number;

  // Bulk-fill reveal state. previousValue tracks the last value handleValueChange()
  // saw, to detect a jump straight to a complete code in one event (autofill/paste)
  // versus normal one-digit-at-a-time typing. revealGeneration is a monotonic token:
  // every cancelReveal() bumps it, so a delayed callback from a superseded reveal can
  // recognize itself as stale and no-op instead of overwriting newer cell contents.
  private previousValue = "";
  private revealGeneration = 0;
  private revealTimers: number[] = [];
  // The value a bulk reveal is currently authoritative for, or null when no
  // reveal owns the display. Lets handleValueChange() and render() recognize
  // a duplicate event for the exact value already being revealed (Bitwarden
  // fires both `input` and `change` for the same fill) and leave it alone,
  // instead of treating it as a fresh state change that cancels the reveal.
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

    // Incomplete markup: bail out without touching anything, so the plain
    // server-rendered input remains usable exactly as if JS never ran.
    if (!box || !labelElement || !field || !totpInput || !toggle || cells.length !== TOTP_LENGTH) return;

    this.wrapper = root;
    this.labelElement = labelElement;
    this.totpInput = totpInput;
    this.cells = cells;
    this.toggle = toggle;

    // Build the backup input fully detached — no live-DOM mutation yet.
    this.backupInput = this.createBackupInput();

    // Snapshot the exact pre-enhancement state, captured before ANY mutation —
    // not reconstructed defaults. Enhancement is about to (a) move a restored
    // backup-shaped value into backupInput and clear totpInput, or (b) sanitize/
    // clamp totpInput's own value in place, and (c) hide/disable it. If anything
    // below throws, rollback must undo exactly what happened, or it could
    // silently destroy a value the user (or a restored session) had entered.
    const snapshot: TotpInputSnapshot = {
      value: totpInput.value,
      disabled: totpInput.disabled,
      hidden: totpInput.hidden,
      autocomplete: totpInput.getAttribute("autocomplete"),
      inputmode: totpInput.getAttribute("inputmode"),
      pattern: totpInput.getAttribute("pattern"),
      labelFor: labelElement.getAttribute("for")!,
      labelText: labelElement.textContent,
    };

    try {
      const raw = totpInput.value;
      const startMode: Mode = raw === "" || TOTP_SHAPED.test(raw) ? "totp" : "backup";
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

      // Only now, after everything else has succeeded: listeners.
      this.totpInput.addEventListener("beforeinput", (event) => this.handleBeforeInput(event as InputEvent));
      this.totpInput.addEventListener("input", () => this.handleValueChange());
      this.totpInput.addEventListener("change", () => this.handleValueChange());
      this.totpInput.addEventListener("focus", () => this.render());
      this.totpInput.addEventListener("blur", () => this.render());
      this.totpInput.addEventListener("keyup", () => this.render());
      this.totpInput.addEventListener("select", () => this.render());
      this.totpInput.addEventListener("click", (event) => this.handleClick(event));
      this.toggle.addEventListener("click", () => this.switchMode(this.mode === "totp" ? "backup" : "totp"));

      root.dataset.otpInitialized = "true";
    } catch (error) {
      // Roll back to the CAPTURED snapshot, not assumed/reconstructed defaults —
      // this is what keeps a restored backup code (or an as-typed, not-yet-
      // sanitized TOTP value) from being silently lost if something throws.
      this.backupInput.remove();
      totpInput.value = snapshot.value;
      totpInput.disabled = snapshot.disabled;
      totpInput.hidden = snapshot.hidden;
      restoreAttribute(totpInput, "autocomplete", snapshot.autocomplete);
      restoreAttribute(totpInput, "inputmode", snapshot.inputmode);
      restoreAttribute(totpInput, "pattern", snapshot.pattern);
      labelElement.setAttribute("for", snapshot.labelFor);
      labelElement.textContent = snapshot.labelText;
      root.classList.remove("is-enhanced");
      delete root.dataset.mode;
      delete root.dataset.otpInitialized;
      throw error;
    }

    // Best-effort additive extras — neither participates in the transactional
    // rollback above; the core six-cell/backup-field enhancement already fully
    // succeeded by this point regardless of what happens here.
    const form = root.closest("form");
    if (form) form.addEventListener("submit", (event) => this.handleSubmit(event));
    // Scoped to this component's own form, not document-wide: a bare
    // getElementById("auth-error") would be ambiguous if a full-page auth form
    // and overlay/auth UI ever coexist or duplicate IDs appear. If there's no
    // owning form or no #auth-error in it, error-feedback is simply skipped —
    // core OTP behavior above doesn't depend on it.
    this.errorElement = form?.querySelector<HTMLElement>("#auth-error") ?? null;
    this.observeAuthError();
  }

  private createBackupInput (): HTMLInputElement {
    const input = document.createElement("input");
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
    // Generated backup codes are 16 hex chars, either the canonical hyphenated
    // grouping or the compact equivalent — accept both, but not a 6-digit TOTP.
    // The backend already normalizes case/separators, so this is a frontend-only
    // sanity check, not a change to what the server accepts.
    input.setAttribute("pattern", "(?:[0-9A-Fa-f]{16}|[0-9A-Fa-f]{4}(?:-[0-9A-Fa-f]{4}){3})");
    input.maxLength = 19; // canonical "a1b2-c3d4-e5f6-a7b8" form is exactly 19 chars
    input.title = "Invalid backup code.";
    input.disabled = true;
    return input;
  }

  private handleValueChange () {
    if (this.mode === "totp") this.sanitize();

    const value = this.totpInput.value;

    if (this.mode === "totp" && this.revealValue !== null && this.revealValue === value) {
      // Duplicate input/change event carrying the exact value a reveal is
      // already displaying (Bitwarden fires both for one fill) — leave the
      // in-flight reveal alone; only keep previousValue in sync.
      this.previousValue = value;
      return;
    }

    const grew = value.length - this.previousValue.length;
    this.previousValue = value;

    // A bulk fill (autofill, or a full-code paste) lands a complete value in a
    // single event; normal one-digit-at-a-time typing never grows by more than
    // one character per event, so this can't misfire on ordinary keystrokes.
    const isBulkFill = this.mode === "totp" && value.length === TOTP_LENGTH && grew > 1;

    if (isBulkFill && !this.prefersReducedMotion()) {
      this.startBulkReveal(value);
    } else {
      this.cancelRevealAndRender();
    }
  }

  private prefersReducedMotion (): boolean {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  /**
   * Reveals an already-complete totpInput value cell-by-cell instead of all at
   * once. The real input's value is already fully set by the caller — only the
   * presentation cells lag behind, purely visually. The six cell boxes stay
   * visible and stationary throughout; only their text and a brief per-cell
   * pop (see restartCellPop()) change. Guarded by revealGeneration so a stale
   * timer from a superseded reveal can never clobber newer content — see
   * cancelReveal(), called by every genuine state change (cancelRevealAndRender()).
   */
  private startBulkReveal (value: string) {
    this.cancelReveal();
    this.revealValue = value;
    const generation = this.revealGeneration;

    this.cells.forEach((cell) => {
      cell.textContent = "";
      cell.classList.remove("active", "empty", "occupied");
    });

    value.split("").forEach((char, index) => {
      const timer = window.setTimeout(() => {
        if (generation !== this.revealGeneration) return; // superseded — a newer edit/render already took over
        const cell = this.cells[index];
        cell.textContent = char;
        this.restartCellPop(cell);
        // Last cell revealed: the reveal is done being authoritative for this
        // value — hand off to a normal render for the final caret state (from
        // the real, current selectionStart), rather than pretending the caret
        // animated along with the reveal.
        if (index === value.length - 1) {
          this.revealValue = null;
          this.render();
        }
      }, index * OtpCodeInput.REVEAL_STEP_MS);
      this.revealTimers.push(timer);
    });
  }

  /** One-shot "digit landed" pop for a single cell — used only during a bulk-fill reveal. */
  private restartCellPop (cell: HTMLElement) {
    cell.classList.remove("bulk-pop");
    void cell.offsetWidth; // restart the animation reliably even if triggered twice in a row
    cell.classList.add("bulk-pop");
    cell.addEventListener("animationend", () => cell.classList.remove("bulk-pop"), { once: true });
  }

  /** Cancels any in-flight bulk reveal and clears any leftover per-cell pop state. */
  private cancelReveal () {
    this.revealGeneration++;
    this.revealTimers.forEach((timer) => window.clearTimeout(timer));
    this.revealTimers = [];
    this.revealValue = null;
    this.cells.forEach((cell) => cell.classList.remove("bulk-pop"));
  }

  /** For genuine state changes (edits, mode switches) that must override an in-flight reveal, unlike a plain render(). */
  private cancelRevealAndRender () {
    this.cancelReveal();
    this.render();
  }

  /**
   * Six-slot overwrite semantics: typing a single digit while the caret targets
   * an already-populated slot replaces that slot instead of inserting and
   * shifting later digits right (which would silently discard the last digit in
   * a fixed-length code). Handled at `beforeinput` so it works with normal
   * browser/mobile text-input semantics rather than reimplementing key handling.
   */
  private handleBeforeInput (event: InputEvent) {
    if (this.mode !== "totp") return;
    if (event.inputType !== "insertText") return; // excludes paste/autofill/composition/replacement
    const data = event.data;
    if (!data || data.length !== 1 || !/^[0-9]$/.test(data)) return; // only a single digit
    if (this.totpInput.selectionStart !== this.totpInput.selectionEnd) return; // collapsed caret only — a selection keeps native replace behavior

    const start = this.totpInput.selectionStart ?? 0;
    const value = this.totpInput.value;

    // Boundary 6 on an already-full value is where the active-cell highlight
    // parks (render() collapses it onto the last cell), so typing there targets
    // that same last slot rather than falling through to append-then-clamp,
    // which would silently no-op instead of overwriting anything.
    const target = value.length === TOTP_LENGTH && start === TOTP_LENGTH ? TOTP_LENGTH - 1 : start;

    if (target >= value.length) return; // genuinely at/after the end with room to grow — normal append; sanitizer clamps to 6 as before

    // Occupied slot: overwrite in place instead of insert-and-shift.
    event.preventDefault();
    this.totpInput.value = value.slice(0, target) + data + value.slice(target + 1);
    this.totpInput.setSelectionRange(target + 1, target + 1);
    this.previousValue = this.totpInput.value;
    this.cancelRevealAndRender();
  }

  /**
   * Strips non-digits and clamps to 6 characters, preserving the caret/selection
   * boundaries (mapped through how many characters were removed ahead of them)
   * instead of letting a blind `value =` reassignment shove the caret to the end.
   */
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

  /**
   * Paints the cells for the current state. Deliberately does NOT cancel an
   * in-flight bulk reveal on its own — render() is wired to harmless events
   * (focus/blur/keyup/select/click) that can fire mid-reveal without
   * representing a real state change (a duplicate Bitwarden `change` event in
   * particular), and unconditionally repainting there would finish the reveal
   * instantly regardless of whether any timer was actually cancelled. Callers
   * that represent a genuine new state (an edit, a mode switch) must cancel
   * explicitly via cancelRevealAndRender() instead.
   */
  private render () {
    if (this.mode !== "totp") return;

    const value = this.totpInput.value;

    // A reveal already owns the display for this exact value — its own timers
    // are progressively painting the cells; don't race them with a full,
    // instant repaint. render() is called again with revealValue cleared once
    // the reveal finishes (see startBulkReveal's last cell).
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

  /**
   * Maps a click's horizontal position to the containing (or nearest) cell
   * *slot*, 0..5, rather than relying on the real input's text metrics to line
   * up with the cells. The caret is authoritative for what's visibly active
   * (a centered blinking bar inside that slot — see the CSS), so a click always
   * targets a whole slot, clamped to the current value's length: clicking a
   * cell past the entered digits parks the caret right after the last digit,
   * not out in empty space with nothing to overwrite.
   */
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

  /** Attribute-only: enables/shows the active input, disables/hides the other. No value clearing — used by both init and switchMode. */
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

  /**
   * Client-side gate for the dedicated backup-code field's `pattern`/`required`
   * constraints. This project disables native browser constraint validation on
   * all forms (SimpleForm's `browser_validations = false`, i.e. every form is
   * rendered with `novalidate`), so those attributes are otherwise decorative —
   * `checkValidity()` still works regardless, since `novalidate` only skips the
   * browser's automatic pre-submit validation walk, not the API itself.
   *
   * Attached to the form during construction, before AuthOverlay attaches its
   * own submit handler (see `bootstrapFormSubmission`), so this runs first and
   * `stopImmediatePropagation()` here also blocks the AJAX submit path.
   */
  private handleSubmit (event: Event) {
    if (this.mode !== "backup" || this.backupInput.checkValidity()) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    this.showError(this.backupInput.title || "Enter a valid backup code.");
    this.backupInput.focus();
  }

  /** Puts a message in this component's own #auth-error, where observeAuthError()'s MutationObserver picks it up. */
  private showError (message: string) {
    if (this.errorElement) this.errorElement.textContent = message;
  }

  /**
   * #auth-error gets populated two different ways — server-rendered on a
   * full-page reload after a failed attempt, or injected later by
   * AuthOverlay.showError() after a failed AJAX submission — so a
   * MutationObserver is what lets one piece of code drive the shake/dismiss
   * feedback for both without OtpCodeInput and AuthOverlay needing any direct
   * reference to each other. Scoped to this.errorElement (this component's own
   * form), not a document-wide lookup — see where it's resolved in the constructor.
   */
  private observeAuthError () {
    const errorEl = this.errorElement;
    if (!errorEl) return;

    const trigger = () => {
      if (errorEl.textContent?.trim()) this.triggerErrorFeedback(errorEl);
    };

    new MutationObserver(trigger).observe(errorEl, { childList: true, characterData: true, subtree: true });
    trigger(); // catches a server-rendered error already present at construction time
  }

  /** Red border + horizontal shake for 2s, then the message itself clears after 5s. */
  private triggerErrorFeedback (errorEl: HTMLElement) {
    window.clearTimeout(this.errorDismissTimer);
    window.clearTimeout(this.errorShakeTimer);

    // Remove-then-reflow-then-reapply so the shake restarts cleanly even if a
    // previous one is still mid-flight (e.g. two failed attempts in a row).
    this.wrapper.classList.remove("otp-code-input-error");
    void this.wrapper.offsetWidth;
    this.wrapper.classList.add("otp-code-input-error");
    this.errorShakeTimer = window.setTimeout(() => {
      this.wrapper.classList.remove("otp-code-input-error");
    }, 2000);

    this.errorDismissTimer = window.setTimeout(() => {
      errorEl.textContent = "";
    }, 5000);
  }
}
