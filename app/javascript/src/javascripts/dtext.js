import { SendQueue } from './send_queue';

const DText = {};

DText.initialze_input = function($element) {
  const $preview = $(".dtext-formatter-preview", $element);
  const $textarea = $(".dtext-formatter-input", $element);
  const $charcount = $(".dtext-formatter-charcount", $element);

  // Tab switching
  $(".dtext-formatter-tabs a", $element).on("click", event => {
    event.preventDefault();
    if($element.attr("data-editing") == "true") {
      $preview.css("min-height", $textarea.outerHeight());
      $element.attr("data-editing", "false");
      update_preview($textarea, $preview);
    } else {
      $element.attr("data-editing", "true");
      $preview.attr("loading", "false");
    }
  });

  // Character count limit
  const limit = $charcount.attr("data-limit") || 0;
  $textarea.on("input.danbooru.formatter", () => {
    const length = ($textarea.val() + "").length;
    $charcount.toggleClass("overfill", length >= limit).attr("data-count", length);
  });

  DText.initialize_formatting_buttons($element);
  $element.attr("data-initialized", "true");
}

DText.initialize_formatting_buttons = function(element) {
  const $textarea = $(".dtext-formatter-input", element);
  
  for(const button of $(".dtext-formatter-buttons a", element)) {
    const $button = $(button);
    const content = $button.attr("data-content");
    $button.off("click");
    $button.on("click", event => {
      event.preventDefault();
      DText.process_formatting(content, $textarea);
    });
  }
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
  $(".dtext-formatter[data-initialized='false']").each((index, element) => {
    DText.initialze_input($(element));
  });
}

$(function () {
  DText.initialize_all_inputs();
});

export default DText;
