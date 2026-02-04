import SVGIcon from "./utility/svg_icon";
import TaskQueue from "./utility/task_queue";

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
  };

  static ButtonOrder = [
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

  isVueComponent = false;

  constructor ($element) {
    this.$wrapper = $element;
    this.$textarea = $element.find("textarea.dtext-formatter-input");
    this.allowColor = $element.data("color") || false;
    this.characterLimit = $element.data("limit") || null;

    $element.data("instance", this);
    this.isVueComponent = this.$textarea.hasClass("dtext-vue");

    this.create();
  }

  // ============================== //
  // ==== Lifecycle Methods ======= //
  // ============================== //

  created = false;

  create () {
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

  destroy () {
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

  buildTabButtons () {
    const tabContainer = $("<div>").addClass("dtext-formatter-tabs")
      .on("click", "button.dtext-formatter-tab", (event) => {
        this.state = $(event.currentTarget).attr("action");
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

  buildFormattingButtons () {
    const buttonContainer = $("<div>")
      .addClass("dtext-formatter-buttons")
      .on("click", "button.dtext-formatter-button", (event) => {
        this.handleFormattingButtonClick($(event.currentTarget));
      });

    for (const buttonType of DTextFormatter.ButtonOrder) {
      if (buttonType === null) {
        $("<div>") // Separator
          .addClass("dtext-formatter-button-separator")
          .appendTo(buttonContainer);
        continue;
      }

      const definition = DTextFormatter.ButtonDefinitions[buttonType];
      if (!definition) continue;

      const $button = $("<button>")
        .addClass("dtext-formatter-button")
        .attr({
          "type": "button",
          "title": definition.title,
          "data-dtext": definition.dtext,
          "aria-label": definition.title,
        })
        .appendTo(buttonContainer);

      $button.append(SVGIcon.render(definition.icon));
    }

    return buttonContainer;
  }

  handleFormattingButtonClick ($button) {
    const dtextTemplate = $button.data("dtext");
    if (!dtextTemplate || typeof dtextTemplate !== "string") return;

    const textarea = this.$textarea.get(0);
    if (!textarea || typeof textarea.setSelectionRange !== "function") return;

    const selectionStart = Math.max(0, textarea.selectionStart ?? 0);
    const selectionEnd = Math.max(selectionStart, textarea.selectionEnd ?? 0);

    // Determine selected text
    const currentValue = this.$textarea.val();
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
    this.$textarea.trigger("input.dtext_formatter").focus();
  }

  // Vue will not detect jQuery-based event triggers.
  // Without triggering a native event, Vue's v-model will not update.
  triggerVueCompatibleEvent ($element) {
    $element[0].dispatchEvent(new Event("input", {bubbles: true}));
  }

  buildPreviewArea () {
    this.$preview = $("<div>")
      .addClass("dtext-formatter-preview");
    return this.$preview;
  }

  buildCounterArea () {
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
      const count = this.$textarea.val().length;
      counter.text(this.characterLimit
        ? `${count} / ${this.characterLimit}`
        : `${count}`,
      );
    });

    if (this.$textarea.val().length > 0)
      this.$textarea.trigger("input.dtext_formatter");

    return footer;
  }


  // ============================ //
  // ===== State Variables ====== //
  // ============================ //

  _definedStates = ["write", "preview"];
  get state () { return this.$wrapper.attr("data-state") || "write"; }
  set state (value) {
    if (!this._definedStates.includes(value)) return;
    this.$wrapper.attr("data-state", value);

    if (value === "preview") {
      this.$preview.height(this.$textarea.height());
      this.updatePreview();
    } else {
      this.$textarea.height(this.$preview.height());
      this.$preview.attr("loading", "false");
    }
  }


  // Preview updating
  _parsedInputCache = null;
  async updatePreview () {
    if (!this.$preview) return;

    // The input is empty, reset everything
    const currentText = this.$textarea.val().trim();
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
    TaskQueue.add(() => {
      $.ajax({
        type: "post",
        url: "/dtext_preview.json",
        dataType: "json",
        data: { body: currentText, allow_color: this.allowColor },
        success: (response) => {

          // The loading was cancelled, since the user toggled back
          // to the editing tab and potentially changed the input
          if (this.$preview.attr("loading") !== "true" || this._parsedInputCache !== currentText)
            return;

          this.$preview
            .attr("loading", "false")
            .html(response.html);
          $(window).trigger("e621:add_deferred_posts", response.posts);
        },
        error: (xhr, status, error) => {
          console.warn("DText preview error:", error);
          this.$preview
            .attr("loading", "false")
            .text("Unable to fetch DText preview.");
          this._parsedInputCache = null;
        },
      }, { name: "DText.update_preview" });
    });
  }

  // ============================ //
  // ==== Static Constructor ==== //
  // =========================== //

  static buildFromTextarea ($textarea) {
    const $wrapper = $("<div>")
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

$(() => {
  for (const one of $(".dtext-formatter")) {
    new DTextFormatter($(one));
  }
});
