import ToastManager from "@/utility/Toast";

let PostReplacement = {};

PostReplacement.initialize_all = function () {
  const $root = $("#c-post-replacements");

  // Expand / collapse a card by clicking its header (but let links navigate).
  $root.on("click", ".replacement-card-header", (e) => {
    if ($(e.target).closest("a").length) return;
    const $card = $(e.currentTarget).closest(".replacement-card");
    const expanded = $card.toggleClass("is-expanded").hasClass("is-expanded");
    $card.find(".replacement-card-toggle").attr("aria-expanded", String(expanded));
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

  $root.on("click", ".replacement-transfer-action", (e) => {
    const $target = $(e.currentTarget);
    e.preventDefault();
    PostReplacement.transfer($target.data("replacement-id"));
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
      ToastManager.notice("Replacement approved.");
      $(".is-current").removeClass("is-current");
      replace_row($row, html);
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to approve the replacement.";
      ToastManager.alert(msg);
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
      ToastManager.notice("Replacement rejected.");
      replace_row($row, html);
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to reject the replacement.";
      ToastManager.alert(msg);
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
      ToastManager.notice("Replacement promoted to a new post.");
      replace_row($row, html);
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to promote the replacement.";
      ToastManager.alert(msg);
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
      ToastManager.notice("Penalization toggled.");
      replace_row($row, html);
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to toggle penalization.";
      ToastManager.alert(msg);
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
      ToastManager.notice("Replacement destroyed.");
      $row.remove();
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to destroy the replacement.";
      ToastManager.alert(msg);
      revert_processing($row);
    });
};

PostReplacement.transfer = function (id) {
  const $row = $(`#replacement-${id}`);
  const raw = prompt("Enter the destination post ID to transfer this replacement to:");
  if (raw === null) return; // cancelled — no toast
  const newPostId = raw.trim();
  if (!newPostId || isNaN(Number(newPostId))) {
    ToastManager.alert("Please enter a valid post ID.");
    return;
  }
  if (!confirm(`Transfer this replacement to post #${newPostId}?`)) return;

  make_processing($row);
  $.ajax({
    type: "PUT",
    url: `/post_replacements/${id}/transfer`,
    data: { new_post_id: newPostId, timeline: $row.hasClass("has-timeline") },
    dataType: "html",
  })
    .done((html) => {
      // ToastManager renders HTML, so link straight to the destination post.
      ToastManager.notice(`Replacement transferred to <a href="/posts/${newPostId}">post #${newPostId}</a>.`);
      if ($row.hasClass("has-timeline")) {
        $row.remove(); // it left this post's timeline — drop it, like destroy
      } else {
        replace_row($row, html); // global list — re-render in place with the new post link
      }
    })
    .fail((data) => {
      const msg = data.responseText?.trim() || "Failed to transfer the replacement.";
      ToastManager.alert(msg);
      revert_processing($row);
    });
};

// Swap a card for its freshly rendered version, preserving whether the user had
// it expanded (the server defaults to expanded only for pending replacements).
function replace_row ($row, html) {
  const wasExpanded = $row.hasClass("is-expanded");
  const $new = $(html);
  if (wasExpanded) $new.addClass("is-expanded");
  $new.find(".replacement-card-toggle").attr("aria-expanded", String($new.hasClass("is-expanded")));
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
