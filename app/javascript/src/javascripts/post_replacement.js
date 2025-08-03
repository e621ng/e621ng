import Utility from "./utility";

let PostReplacement = {};
PostReplacement.initialize_all = function () {
  PostReplacement.set_initial_section_state();
  const actions = [
    { selector: ".replacement-approve-action", handler: (e, $target) => { PostReplacement.approve($target.data("replacement-id"), $target.data("penalize"), true); }},
    { selector: ".replacement-reject-action", handler: (e, $target) => { PostReplacement.reject($target.data("replacement-id")); }},
    { selector: ".replacement-promote-action", handler: (e, $target) => { PostReplacement.promote($target.data("replacement-id")); }},
    { selector: ".replacement-toggle-penalize-action", handler: (e, $target) => { PostReplacement.toggle_penalize($target); }},
    { selector: ".replacement-destroy-action", handler: (e, $target) => { PostReplacement.destroy($target.data("replacement-id")); }},
    { selector: ".replacement-silent-approve-action", handler: (e, $target) => { PostReplacement.approve($target.data("replacement-id"), $target.data("penalize"), false); }},
    { selector: ".replacement-transfer-action", handler: (e, $target) => { PostReplacement.transfer($target.data("replacement-id")); } },
    { selector: ".replacement-note-action", handler: (e, $target) => { PostReplacement.note($target.data("replacement-id"), $target.data("current-note")); } },
    { selector: ".toggle-expanded-button", handler: (e, $target) => {
      const id = $target.data("replacement-id");
      PostReplacement.toggle_section(id);
    }},
  ];

  actions.forEach(({ selector, handler }) => {
    $(document).on("click", selector, function (e) {
      const $target = $(this);
      e.preventDefault();
      handler(e, $target);
    });
  });
};

PostReplacement.note = function (id, current_note) {
  const $row = $(`#replacement-${id}`);

  let prompt_message = "Enter a note:";
  let default_value = "";
  if (typeof current_note === "string" && current_note.trim() !== "") {
    prompt_message = "This replacement already has a note. Enter a new note (leave blank to remove):";
    default_value = current_note;
  }
  const note_text = prompt(prompt_message, default_value);
  if (!note_text) {
    Utility.notice("Note cancelled.");
    return;
  }
  make_processing($row);
  $.ajax({
    type: "PUT",
    url: `/post_replacements/${id}/note`,
    data: {
      note_content: note_text,
    },
    dataType: "html",
  })
    .done((html) => {
      const expanded = get_section_state($row);
      $row.replaceWith(
        (() => {
          const $el = $(html);
          set_section_state($el, expanded);
          return $el;
        })(),
      );
      Utility.notice("Note added.");
    })
    .fail((data) => {
      const msg = extractErrorMessage(data.responseText, "Failed to add note to the replacement.");
      Utility.error(msg);
      revert_processing($row);
    });
};

PostReplacement.transfer = function (id) {
  const $row = $(`#replacement-${id}`);
  const newPostId = prompt("Enter the new post ID to transfer this replacement to:");
  if (!newPostId) {
    Utility.notice("Transfer cancelled.");
    return;
  }
  make_processing($row);
  $.ajax({
    type: "PUT",
    url: `/post_replacements/${id}/transfer`,
    data: {
      new_post_id: newPostId,
    },
    dataType: "html",
  })
    .done((html) => {
      const expanded = get_section_state($row);
      $row.replaceWith(
        (() => {
          const $el = $(html);
          set_section_state($el, expanded);
          return $el;
        })(),
      );
      Utility.notice("Replacement transferred.");
    })
    .fail((data) => {
      const msg = extractErrorMessage(data.responseText, "Failed to transfer the replacement.");
      Utility.error(msg);
      revert_processing($row);
    });
};

PostReplacement.approve = function (id, penalize_current_uploader, credit_replacer) {
  const $row = $(`#replacement-${id}`);
  make_processing($row);
  $.ajax({
    type: "PUT",
    url: `/post_replacements/${id}/approve`,
    data: {
      penalize_current_uploader: penalize_current_uploader,
      credit_replacer: credit_replacer,
    },
    dataType: "html",
  })
    .done((html) => {
      const expanded = get_section_state($row);
      $row.replaceWith(
        (() => {
          const $el = $(html);
          set_section_state($el, expanded);
          return $el;
        })(),
      );
      Utility.notice("Replacement approved.");
    })
    .fail((data) => {
      const msg = extractErrorMessage(data.responseText, "Failed to approve the replacement.");
      Utility.error(msg);
      revert_processing($row);
    });
};

PostReplacement.reject = function (id) {
  if (!confirm("Are you sure you want to reject this replacement?")) return;
  const $row = $(`#replacement-${id}`);
  make_processing($row);
  $.ajax({
    type: "PUT",
    url: `/post_replacements/${id}/reject`,
    dataType: "html",
  })
    .done((html) => {
      const expanded = get_section_state($row);
      $row.replaceWith(
        (() => {
          const $el = $(html);
          set_section_state($el, expanded);
          return $el;
        })(),
      );
      Utility.notice("Replacement rejected.");
    })
    .fail((data) => {
      const msg = extractErrorMessage(data.responseText, "Failed to reject the replacement.");
      Utility.error(msg);
      revert_processing($row);
    });
};

PostReplacement.promote = function (id) {
  if (!confirm("Are you sure you want to promote this replacement?")) return;
  const $row = $(`#replacement-${id}`);
  make_processing($row);
  $.ajax({
    type: "POST",
    url: `/post_replacements/${id}/promote`,
    dataType: "html",
  })
    .done((html) => {
      const expanded = get_section_state($row);
      $row.replaceWith(
        (() => {
          const $el = $(html);
          set_section_state($el, expanded);
          return $el;
        })(),
      );
      Utility.notice("Replacement promoted to a new post.");
    })
    .fail((data) => {
      const msg = extractErrorMessage(data.responseText, "Failed to promote the replacement.");
      Utility.error(msg);
      revert_processing($row);
    });
};

PostReplacement.toggle_penalize = function ($target) {
  const id = $target.data("replacement-id");
  const $row = $(`#replacement-${id}`);
  $target.addClass("disabled-link");
  $.ajax({
    type: "PUT",
    url: `/post_replacements/${id}/toggle_penalize`,
    dataType: "html",
  })
    .done((html) => {
      const expanded = get_section_state($row);
      $row.replaceWith(
        (() => {
          const $el = $(html);
          set_section_state($el, expanded);
          return $el;
        })(),
      );
      Utility.notice("Penalization toggled.");
    })
    .fail((data) => {
      const msg = extractErrorMessage(data.responseText, "Failed to toggle penalization.");
      Utility.error(msg);
      $target.removeClass("disabled-link");
    });
};

PostReplacement.destroy = function (id) {
  if (!confirm("Are you sure you want to destroy this replacement?")) return;
  const $row = $(`#replacement-${id}`);
  make_processing($row);
  $.ajax({
    type: "DELETE",
    url: `/post_replacements/${id}`,
    dataType: "html",
  })
    .done(() => {
      Utility.notice("Replacement destroyed.");
      $row.remove();
    })
    .fail((data) => {
      const msg = extractErrorMessage(data.responseText, "Failed to destroy the replacement.");
      Utility.error(msg);
      revert_processing($row);
    });
};

PostReplacement.toggle_section = function (id) {
  const $row = $(`#replacement-${id}`);
  $row.find(".replacement-collapsible").toggle();
  $row.find(".replacement-expandable").toggle();
};

PostReplacement.set_initial_section_state = function () {
  const isMobile = window.matchMedia("(max-width: 50rem)").matches;

  $(".mobile-replacement-row").each(function () {
    const $row = $(this);
    // Find the collapsible/expandable elements within this row, regardless of nesting
    const $collapsible = $row.find(".replacement-collapsible");
    const $expandable = $row.find(".replacement-expandable");
    if (isMobile) {
      $collapsible.hide();
      $expandable.show();
    } else {
      $collapsible.show();
      $expandable.hide();
    }
  });
};

function make_processing ($row) {
  $row.removeClass("replacement-pending-row").addClass("replacement-processing-row");
  $row.find(".replacement-status-value-box").text("processing");
  $row.find(".replacement-actions a").addClass("disabled-link");
}

function revert_processing ($row) {
  $row.removeClass("replacement-processing-row");
  $row.find(".replacement-status-value-box").text("error");
  $row.find(".replacement-actions a").removeClass("disabled-link");
}

function get_section_state ($row) {
  // Returns true if expanded, false if collapsed
  return $row.find(".replacement-collapsible").is(":visible");
}

function set_section_state ($row, expanded) {
  if (expanded) {
    $row.find(".replacement-collapsible").show();
    $row.find(".replacement-expandable").hide();
  } else {
    $row.find(".replacement-collapsible").hide();
    $row.find(".replacement-expandable").show();
  }
}

function extractErrorMessage (responseText, fallbackMsg) {
  if (!responseText) return fallbackMsg;

  // Try to parse JSON and extract message
  try {
    const json = JSON.parse(responseText);
    if (json && typeof json.message === "string" && json.message.trim() !== "") {
      return json.message.trim();
    }
  } catch {
    // Not JSON, continue
  }

  // If it looks like HTML, try to extract the first <p> content
  if (responseText.match(/<html[\s\S]*<\/html>/i) || responseText.match(/<!DOCTYPE html>/i)) {
    // Try to extract the first <p>...</p>
    const match = responseText.match(/<p>(.*?)<\/p>/i);
    if (match && match[1]) {
      return match[1].replace(/<[^>]+>/g, "").trim();
    }
    return fallbackMsg;
  }

  return responseText.trim();
}

$(function () {
  if ($("#c-post-replacements").length) PostReplacement.initialize_all();
});

export default PostReplacement;
