import DeferredPostLoader from "@/core/DeferredPostLoader";
import type { DeferredPostData } from "@/models/PostCache";
import HTTP from "@/utility/HTTP";
import Logger from "@/utility/Logger";
import SVGIcon from "@/utility/SVGIcon";
import TaskQueue, { TaskCancelled } from "@/utility/TaskQueue";

interface ButtonDefinition {
  dtext: string;
  icon: string;
  title: string;
}

type ButtonName = keyof typeof DTextFormatter.ButtonDefinitions;
type FormatterState = "write" | "preview";

interface DTextPreviewResponse {
  html: string;
  posts: Record<number, DeferredPostData>;
}

const PREVIEW_FALLBACK_ERROR = "Unable to fetch DText preview.";

function isFormatterState (value: unknown): value is FormatterState {
  return value === "write" || value === "preview";
}

export default class DTextFormatter {

  static ButtonDefinitions = {
    bold: { dtext: "[b]%selection%[/b]", icon: "bold", title: "Bold" },
    italic: { dtext: "[i]%selection%[/i]", icon: "italic", title: "Italic" },
    underline: { dtext: "[u]%selection%[/u]", icon: "underline", title: "Underline" },
    strikethrough: { dtext: "[s]%selection%[/s]", icon: "strikethrough", title: "Strikethrough" },

    heading: { dtext: "h2. %selection%", icon: "heading", title: "Heading" },
    spoiler: { dtext: "[spoiler]%selection%[/spoiler]", icon: "spoiler", title: "Spoiler" },
    code: { dtext: "[code]%selection%[/code]", icon: "code", title: "Code" },
    quote: { dtext: "[quote]%selection%[/quote]", icon: "quote", title: "Quote" },
  } as const satisfies Record<string, ButtonDefinition>;

  static ButtonOrder: readonly (ButtonName | null)[] = [
    "bold",
    "italic",
    "underline",
    "strikethrough",
    null,
    "heading",
    "spoiler",
    "code",
    "quote",
  ];

  public isVueComponent = false;

  private $wrapper: JQuery<HTMLDivElement>;
  private $textarea: JQuery<HTMLTextAreaElement>;
  private $preview!: JQuery<HTMLDivElement>; // Assigned in create()
  private allowColor: boolean;
  private characterLimit: number | null;

  private Logger: Logger;

  constructor ($element: JQuery<HTMLDivElement>) {
    this.Logger = new Logger("DText");

    this.$wrapper = $element;
    this.$textarea = $element.find<HTMLTextAreaElement>("textarea.dtext-formatter-input");
    this.allowColor = Boolean($element.data("color"));
    this.characterLimit = Number($element.data("limit")) || null;

    $element.data("instance", this);
    this.isVueComponent = this.$textarea.hasClass("dtext-vue");

    this.create();
  }

  private get text (): string {
    return String(this.$textarea.val() ?? "");
  }

  // ============================== //
  // ==== Lifecycle Methods ======= //
  // ============================== //

  created = false;

  create (): void {
    if (this.created) return;

    const tabContainer = this.buildTabButtons();
    const buttonContainer = this.buildFormattingButtons();
    const previewArea = this.buildPreviewArea();
    const footer = this.buildCounterArea();

    this.$wrapper
      .append([
        tabContainer,
        buttonContainer,
        previewArea,
        footer,
      ])
      .removeClass("pending");

    this.created = true;
  }

  destroy (): void {
    if (!this.created) return;
    this._parsedInputCache = null;
    this.$textarea.off("input.dtext_formatter");

    // Remove created DOM elements
    this.$wrapper.find(".dtext-formatter-footer").remove();
    this.$wrapper.find(".dtext-formatter-preview").remove();
    this.$wrapper.find(".dtext-formatter-buttons").remove();
    this.$wrapper.find(".dtext-formatter-tabs").remove();

    // Restore original state
    this.$wrapper.removeAttr("data-state");
    this.$wrapper.addClass("pending");

    this.created = false;
  }


  // ============================== //
  // ==== Building UI Elements ==== //
  // ============================== //

  buildTabButtons (): JQuery<HTMLElement> {
    const tabContainer = $("<div>").addClass("dtext-formatter-tabs")
      .on("click", "button.dtext-formatter-tab", (event) => {
        const action = $(event.currentTarget).attr("action");
        if (isFormatterState(action)) this.state = action;
      });

    for (const tabName of ["Write", "Preview"]) {
      $("<button>")
        .addClass("dtext-formatter-tab")
        .text(tabName)
        .attr({
          type: "button",
          action: tabName.toLowerCase(),
        })
        .appendTo(tabContainer);
    }

    return tabContainer;
  }

  buildFormattingButtons (): JQuery<HTMLElement> {
    const buttonContainer = $("<div>")
      .addClass("dtext-formatter-buttons")
      .on("click", "button.dtext-formatter-button", (event) => {
        const name = $(event.currentTarget).attr("data-button");
        if (name && Object.prototype.hasOwnProperty.call(DTextFormatter.ButtonDefinitions, name))
          this.handleFormattingButtonClick(name as ButtonName);
      });

    for (const buttonType of DTextFormatter.ButtonOrder) {
      if (buttonType === null) {
        $("<div>") // Separator
          .addClass("dtext-formatter-button-separator")
          .appendTo(buttonContainer);
        continue;
      }

      const definition = DTextFormatter.ButtonDefinitions[buttonType];
      const $button = $("<button>")
        .addClass("dtext-formatter-button")
        .attr({
          "type": "button",
          "title": definition.title,
          "data-button": buttonType,
          "aria-label": definition.title,
        })
        .appendTo(buttonContainer);

      const icon = SVGIcon.render(definition.icon);
      if (icon) $button.append(icon);
    }

    return buttonContainer;
  }

  handleFormattingButtonClick (name: ButtonName): void {
    const dtextTemplate: string = DTextFormatter.ButtonDefinitions[name].dtext;

    const textarea = this.$textarea.get(0);
    if (!textarea || typeof textarea.setSelectionRange !== "function") return;

    const selectionStart = Math.max(0, textarea.selectionStart ?? 0);
    const selectionEnd = Math.max(selectionStart, textarea.selectionEnd ?? 0);

    // Determine selected text
    const currentValue = this.text;
    const selectedText = currentValue.substring(selectionStart, selectionEnd);
    const dtextToInsert = dtextTemplate.replace("%selection%", selectedText);

    // Substitute new text content
    const newValue = currentValue.substring(0, selectionStart) + dtextToInsert + currentValue.substring(selectionEnd);
    this.$textarea.val(newValue);

    // Update cursor position with proper validation
    const contentPlaceholderIndex = dtextTemplate.indexOf("%selection%");
    if (contentPlaceholderIndex !== -1) {
      const contentStartPos = selectionStart + contentPlaceholderIndex;
      const contentEndPos = contentStartPos + selectedText.length;
      textarea.setSelectionRange(contentStartPos, contentEndPos);
    } else {
      // Fallback: position cursor at end of inserted content
      const newCursorPos = selectionStart + dtextToInsert.length;
      textarea.setSelectionRange(newCursorPos, newCursorPos);
    }

    if (this.isVueComponent) this.triggerVueCompatibleEvent(this.$textarea);
    this.$textarea.trigger("input.dtext_formatter").trigger("focus");
  }

  // Vue will not detect jQuery-based event triggers.
  // Without triggering a native event, Vue's v-model will not update.
  triggerVueCompatibleEvent ($element: JQuery<HTMLTextAreaElement>): void {
    $element[0].dispatchEvent(new Event("input", { bubbles: true }));
  }

  buildPreviewArea (): JQuery<HTMLDivElement> {
    this.$preview = $<HTMLDivElement>("<div>")
      .addClass("dtext-formatter-preview");
    return this.$preview;
  }

  buildCounterArea (): JQuery<HTMLElement> {
    const footer = $("<div>")
      .addClass("dtext-formatter-footer");

    // Hint
    $("<span>")
      .addClass("dtext-formatter-hint")
      .html('<a href="/help/dtext" target="_blank" rel="noopener" tabindex="-1">DText</a> formatting supported.')
      .appendTo(footer);

    // Character Counter
    const counter = $("<span>")
      .addClass("dtext-formatter-counter")
      .appendTo(footer);

    this.$textarea.on("input.dtext_formatter", () => {
      const count = this.text.length;
      counter.text(this.characterLimit
        ? `${count} / ${this.characterLimit}`
        : `${count}`,
      );
    });

    if (this.text.length > 0)
      this.$textarea.trigger("input.dtext_formatter");

    return footer;
  }


  // ============================ //
  // ===== State Variables ====== //
  // ============================ //

  get state (): FormatterState {
    const value = this.$wrapper.attr("data-state");
    return isFormatterState(value) ? value : "write";
  }

  set state (value: FormatterState) {
    if (!isFormatterState(value)) return;
    this.$wrapper.attr("data-state", value);

    if (value === "preview") {
      this.$preview.height(this.$textarea.height() ?? 0);
      void this.updatePreview();
    } else {
      this.$textarea.height(this.$preview.height() ?? 0);
      this.$preview.attr("loading", "false");
    }
  }


  // Preview updating
  _parsedInputCache: string | null = null;
  async updatePreview (): Promise<void> {
    if (!this.$preview) return;

    // The input is empty, reset everything
    const currentText = this.text.trim();
    if (!currentText) {
      this.$preview.empty();
      this._parsedInputCache = null;
      return;
    }

    // The input is identical to the previous lookup
    if (this._parsedInputCache === currentText) return;
    this._parsedInputCache = currentText;

    this.$preview
      .html("")
      .attr("loading", "true");

    // Load preview content
    try {
      await TaskQueue.add(() => this.fetchPreview(currentText), { name: "DText.update_preview" });
    } catch (error) {
      if (!(error instanceof TaskCancelled)) throw error;
    }
  }

  private async fetchPreview (currentText: string): Promise<void> {
    try {
      const response = await HTTP.post("/dtext_preview.json", new URLSearchParams({
        body: currentText,
        allow_color: String(this.allowColor),
      }));

      // Surface the server's reason (login required, body too long, throttled).
      if (!response.ok) {
        this.showPreviewError(await HTTP.errorMessage(response, PREVIEW_FALLBACK_ERROR));
        return;
      }

      const data: DTextPreviewResponse = await response.json();
      this.Logger.log("Preview response received", data);

      // The loading was cancelled, since the user toggled back
      // to the editing tab and potentially changed the input
      if (this.$preview.attr("loading") !== "true" || this._parsedInputCache !== currentText)
        return;

      this.$preview
        .attr("loading", "false")
        .html(data.html);
      DeferredPostLoader.loadPostData(data.posts);
      DeferredPostLoader.renderDTextThumbnails();
    } catch (error) {
      console.error("DText preview error:", error);
      this.showPreviewError(PREVIEW_FALLBACK_ERROR);
    }
  }

  private showPreviewError (message: string): void {
    this.$preview
      .attr("loading", "false")
      .text(message);
    this._parsedInputCache = null;
  }

  // ============================ //
  // ==== Static Constructor ==== //
  // =========================== //

  static buildFromTextarea ($textarea: JQuery<HTMLTextAreaElement>): DTextFormatter {
    const $wrapper = $<HTMLDivElement>("<div>")
      .addClass("dtext-formatter pending")
      .attr({
        "data-color": $textarea.data("color") || false,
        "data-limit": $textarea.data("limit") || null,
      })
      .insertAfter($textarea);

    $textarea
      .addClass("dtext-formatter-input")
      .appendTo($wrapper);

    return new DTextFormatter($wrapper);
  }
}
