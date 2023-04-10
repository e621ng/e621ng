import { SendQueue } from './send_queue';

const DText = {};

DText.buttons = [
  { icon: "f032",   title: "Bold",            content: "[b]%selection%[/b]" },
  { icon: "f033",   title: "Italics",         content: "[i]%selection%[/i]" },
  { icon: "f0cc",   title: "Strikethrough",   content: "[s]%selection%[/s]" },
  { icon: "f0cd",   title: "Underline",       content: "[u]%selection%[/u]" },
  null,
  { icon: "f1dc",   title: "Header",          content: "h2.%selection%" },
  { icon: "f070",   title: "Spoiler",         content: "[spoiler]%selection%[/spoiler]" },
  { icon: "f121",   title: "Code",            content: "[code]%selection%[/code]" },
  { icon: "f10e",   title: "Quote",           content: "[quote]%selection%[/quote]" },
];

/**
 * Set up the wrapper for the target input with
 * DText preview and formatting buttons.
 * @param {JQuery<HTMLElement>} textarea Target input
 */
DText.create_wrapper = function(textarea) {
  const wrapper = $("<div>")
    .addClass("dtext-formatter")
    .attr({ "data-editing": "true", })
    .insertBefore(textarea);
  
  build_tabs(wrapper);
  build_buttons(wrapper, textarea);
  
  textarea
    .addClass("dtext-formatter-input")
    .appendTo(wrapper);
  
  build_preview(wrapper, textarea);
  build_charcounter(wrapper, textarea);
  textarea.attr("data-initialized", "true");
}

/**
 * Unwraps the textarea and restores it back
 * to its original state.
 * @param {JQuery<HTMLElement>} textarea Target input
 */
DText.destroy_wrapper = function(textarea) {
  const wrapper = textarea.parents(".dtext-formatter");
  if(!wrapper.length) return;
  
  textarea
    .insertAfter(wrapper)
    .removeClass("dtext-formatter-input")
    .off("input.danbooru.formatter");
  wrapper.remove();
}

function build_tabs(wrapper) {
  $("<div>")
    .addClass("dtext-formatter-tabs")
    .html(
      `<a data-action="edit" role="tab">Write</a>` +
      `<a data-action="show" role="tab">Preview</a>`
    )
    .on("click", "a", (event) => {
      event.preventDefault();
      wrapper.trigger("e621:toggle");
    })
    .appendTo(wrapper);
}

function build_buttons(wrapper, textarea) {
  const container = $("<div>")
    .addClass("dtext-formatter-buttons")
    .attr({ "role": "toolbar", })
    .appendTo(wrapper);
  
  wrapper.on("e621:reload", () => {
    container.html("");
    for(const button of DText.buttons) {

      // Spacer
      if(button == null) {
        $("<span>").appendTo(container);
        continue;
      }
  
      // Normal button
      $("<a>")
        .html("&#x" + button.icon)
        .attr({
          "title": button.title,
          "role": "button",
        })
        .on("click", (event) => {
          event.preventDefault();
          DText.process_formatting(button.content, textarea);
        })
        .appendTo(container);
    }
  });
  wrapper.trigger("e621:reload");
}

function build_preview(wrapper, textarea) {
  const preview = $("<div>")
    .addClass("dtext-formatter-preview dtext-container")
    .appendTo(wrapper);
  
  wrapper.on("e621:toggle", () => {
    if(wrapper.attr("data-editing") == "true") {
      preview.css("min-height", textarea.outerHeight());
      wrapper.attr("data-editing", "false");
      update_preview(textarea, preview);
    } else {
      wrapper.attr("data-editing", "true");
      preview.attr("loading", "false");
    }
  });
}

function build_charcounter(wrapper, textarea) {
  const limit = textarea.attr("data-limit") || 0;
  const charcount = $("<div>")
    .addClass("dtext-formatter-charcount")
    .attr({
      "data-limit": limit,
      "data-count": (textarea.val() + "").length,
    })
    .appendTo(wrapper);
  
  textarea.on("input.danbooru.formatter", () => {
    const length = (textarea.val() + "").length;
    charcount
      .toggleClass("overfill", length >= limit)
      .attr("data-count", length);
  });
}

/** Refreshes the preview field to match the provided input */
function update_preview(input, preview) {
  const currentText = input.val().trim();
  
  // The input is empty, reset everything
  if(!currentText) {
    preview.text("");
    input.removeData("cache");
    return;
  }
  
  // The input is identical to the previous lookup
  if(input.data("cache") == currentText) return;
  input.data("cache", currentText);
  
  preview
    .html("")
    .attr("loading", "true");
  SendQueue.add(() => {
    $.ajax({
      type: "post",
      url: "/dtext_preview",
      dataType: "json",
      data: { body: currentText },
      success: (response) => {
      
        // The loading was cancelled, since the user toggled back
        // to the editing tab and potentially changed the input
        if(preview.attr("loading") !== "true" || input.data("cache") !== currentText)
          return;
        
        preview
          .attr("loading", "false")
          .html(response.html);
        $(window).trigger("e621:add_deferred_posts", response.posts);
      },
      error: () => {
        preview
          .attr("loading", "false")
          .text("Unable to fetch DText preview.");
        input.removeData("cache");
      }
    });
  });
}

/**
 * Processes a formatting button click.
 * @param {string} content Button action, ex. `[b]%selection%[/b]`
 * @param {JQuery<HTMLElement>} input Input element to alter
 */
DText.process_formatting = function (content, input) {
  const currentText = input.val() + "";
  const position = {
    start: input.prop("selectionStart"),
    end: input.prop("selectionEnd"),
  };
  
  const offset = {
    start: content.indexOf("%selection%"),
    end: content.length - (content.indexOf("%selection%") + 11),
  };
  
  content = content.replace(/%selection%/g, currentText.substring(position.start, position.end));
  input.trigger("focus");

  // This is a workaround for a Firefox bug (prior to version 89)
  // Check https://bugzilla.mozilla.org/show_bug.cgi?id=1220696 for more information
  if (!document.execCommand("insertText", false, content))
    input.val(currentText.substring(0, position.start) + content + currentText.substring(position.end, currentText.length));
  
  input.prop("selectionStart", position.start + offset.start);
  input.prop("selectionEnd", position.start + content.length - offset.end);
  input.trigger("focus");
}

/** Add formatters to all appropriate inputs */
DText.initialize_all_inputs = function() {
  $("textarea.dtext[data-initialized='false']").each((index, element) => {
    DText.create_wrapper($(element));
  });
}

$(function () {
  DText.initialize_all_inputs();
});

export default DText;
