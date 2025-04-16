import Utility from "./utility";

let PostReplacement = {};

PostReplacement.initialize_all = function () {
  $(".replacement-approve-action").on("click", (e) => {
    const $target = $(e.target);
    e.preventDefault();
    PostReplacement.approve($target.data("replacement-id"), $target.data("penalize"));
  });

  $(".replacement-reject-action").on("click", (e) => {
    const $target = $(e.target);
    e.preventDefault();
    PostReplacement.reject($target.data("replacement-id"));
  });

  $(".replacement-promote-action").on("click", (e) => {
    const $target = $(e.target);
    e.preventDefault();
    PostReplacement.promote($target.data("replacement-id"));
  });

  $(".replacement-toggle-penalize-action").on("click", (e) => {
    const $target = $(e.target);
    e.preventDefault();
    PostReplacement.toggle_penalize($target);
  });

  $(".replacement-destroy-action").on("click", (e) => {
    const $target = $(e.target);
    const id = $target.data("replacement-id");
    e.preventDefault();
    PostReplacement.destroy(id);
  });
};

PostReplacement.approve = function (id, penalize_current_uploader) {
  const $row = $(`#replacement-${id}`);
  make_processing($row);
  $.ajax({
    type: "PUT",
    url: `/post_replacements/${id}/approve`,
    data: { penalize_current_uploader },
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
