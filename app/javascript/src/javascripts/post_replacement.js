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
    { selector: ".toggle-expanded-button", handler: (e, $target) => { const id = $target.data("replacement-id");  PostReplacement.toggle_section(id); }},
  ];

  actions.forEach(({ selector, handler }) => {
    $(document).on("click", selector, function(e) {
      const $target = $(this);
      e.preventDefault();
      handler(e, $target);
    });
  });
};

PostReplacement.note =  function (id, current_note) {
  const $row = $(`#replacement-${id}`);
  
  let prompt_message = "Enter a note:";
  let default_value = "";
  if (current_note && current_note.trim() !== "") {
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
      note_content: note_text
    },
    dataType: "html",
  })
    .done((html) => {
      Utility.notice("Note added.");
      $row.replaceWith(html);
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to add note to the replacement.";
      Utility.error(msg);
      revert_processing($row);
    });
}

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
      new_post_id: newPostId
    },
    dataType: "html",
  })
    .done((html) => {
      Utility.notice("Replacement transferred.");
      $row.replaceWith(html);
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to transfer the replacement.";
      Utility.error(msg);
      revert_processing($row);
    });
}

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
      Utility.notice("Replacement approved.");
      $row.replaceWith(html);
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to approve the replacement.";
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
      Utility.notice("Replacement rejected.");
      $row.replaceWith(html);
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to reject the replacement.";
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
      Utility.notice("Replacement promoted to a new post.");
      $row.replaceWith(html);
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to promote the replacement.";
      Utility.error(msg);
      revert_processing($row);
    });
};

PostReplacement.toggle_penalize = function ($target) {
  const id = $target.data("replacement-id");
  $target.addClass("disabled-link");
  $.ajax({
    type: "PUT",
    url: `/post_replacements/${id}/toggle_penalize`,
    dataType: "html",
  })
    .done((html) => {
      Utility.notice("Penalization toggled.");
      $(`#replacement-${id}`).replaceWith(html);
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to toggle penalization.";
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
      const msg = data.responseText?.trim() || "Failed to destroy the replacement.";
      Utility.error(msg);
      revert_processing($row);
    });
};

PostReplacement.toggle_section = function(id) {
  const $row = $(`#replacement-${id}`);
  $row.find('.replacement-collapsible').toggle();
  $row.find('.replacement-expandable').toggle();
};

PostReplacement.set_initial_section_state = function() {
  const isMobile = window.matchMedia("(max-width: 600px)").matches;
  $(".replacement-section-top").each(function() {
    const $row = $(this);
    if (isMobile) {
      $row.find('.replacement-collapsible').hide();
      $row.find('.replacement-expandable').show();
    } else {
      $row.find('.replacement-collapsible').show();
      $row.find('.replacement-expandable').hide();
    }
  });
};

function make_processing ($row) {
  $row.removeClass("replacement-pending-row").addClass("replacement-processing-row");
  $row.find(".replacement-status").text("processing");
  $row.find(".pending-links a").addClass("disabled-link");
}

function revert_processing ($row) {
  $row.removeClass("replacement-processing-row");
  $row.find(".replacement-status").text("error");
  $row.find(".pending-links a").removeClass("disabled-link");
}

$(function () {
  if ($("#c-post-replacements").length) PostReplacement.initialize_all();
});

export default PostReplacement;
