let PostReplacement = {};

PostReplacement.initialize_all = function () {
  const $root = $("#c-post-replacements");

  // Expand / collapse a card by clicking its header (but let links navigate).
  $root.on("click", ".replacement-card-header", (e) => {
    if ($(e.target).closest("a").length) return;
    $(e.currentTarget).closest(".replacement-card").toggleClass("is-expanded");
  });

  // Actions are delegated from the container so they survive the replaceWith
  // swaps below (freshly rendered cards are bound without re-initializing).
  $root.on("click", ".replacement-approve-action", (e) => {
    const $target = $(e.currentTarget);
    e.preventDefault();
    PostReplacement.approve($target.data("replacement-id"), $target.data("penalize"));
  });

  $root.on("click", ".replacement-reject-action", (e) => {
    const $target = $(e.currentTarget);
    e.preventDefault();
    PostReplacement.reject($target.data("replacement-id"));
  });

  $root.on("click", ".replacement-promote-action", (e) => {
    const $target = $(e.currentTarget);
    e.preventDefault();
    PostReplacement.promote($target.data("replacement-id"));
  });

  $root.on("click", ".replacement-toggle-penalize-action", (e) => {
    const $target = $(e.currentTarget);
    e.preventDefault();
    PostReplacement.toggle_penalize($target);
  });

  $root.on("click", ".replacement-destroy-action", (e) => {
    const $target = $(e.currentTarget);
    e.preventDefault();
    PostReplacement.destroy($target.data("replacement-id"));
  });
};

PostReplacement.approve = function (id, penalize_current_uploader) {
  const $row = $(`#replacement-${id}`);
  make_processing($row);
  $.ajax({
    type: "PUT",
    url: `/post_replacements/${id}/approve`,
    data: { penalize_current_uploader, timeline: $row.hasClass("has-timeline") },
    dataType: "html",
  })
    .done((html) => {
      E621.Toast.notice("Replacement approved.");
      replace_row($row, html);
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to approve the replacement.";
      E621.Toast.alert(msg);
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
    data: { timeline: $row.hasClass("has-timeline") },
    dataType: "html",
  })
    .done((html) => {
      E621.Toast.notice("Replacement rejected.");
      replace_row($row, html);
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to reject the replacement.";
      E621.Toast.alert(msg);
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
    data: { timeline: $row.hasClass("has-timeline") },
    dataType: "html",
  })
    .done((html) => {
      E621.Toast.notice("Replacement promoted to a new post.");
      replace_row($row, html);
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to promote the replacement.";
      E621.Toast.alert(msg);
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
    data: { timeline: $row.hasClass("has-timeline") },
    dataType: "html",
  })
    .done((html) => {
      E621.Toast.notice("Penalization toggled.");
      replace_row($row, html);
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to toggle penalization.";
      E621.Toast.alert(msg);
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
      E621.Toast.notice("Replacement destroyed.");
      $row.remove();
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to destroy the replacement.";
      E621.Toast.alert(msg);
      revert_processing($row);
    });
};

// Swap a card for its freshly rendered version, preserving whether the user had
// it expanded (the server defaults to expanded only for pending replacements).
function replace_row ($row, html) {
  const wasExpanded = $row.hasClass("is-expanded");
  const $new = $(html);
  if (wasExpanded) $new.addClass("is-expanded");
  $row.replaceWith($new);
}

function make_processing ($row) {
  $row.removeClass("is-pending").addClass("is-processing");
  $row.find(".replacement-status").text("processing");
  $row.find(".replacement-card-actions a").addClass("disabled-link");
}

function revert_processing ($row) {
  $row.removeClass("is-processing");
  $row.find(".replacement-status").text("error");
  $row.find(".replacement-card-actions a").removeClass("disabled-link");
}

$(function () {
  if ($("#c-post-replacements").length) PostReplacement.initialize_all();
});

export default PostReplacement;
