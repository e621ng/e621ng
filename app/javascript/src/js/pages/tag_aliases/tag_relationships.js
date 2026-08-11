class TagRelationships {
  static approve (e) {
    e.preventDefault();
    const $e = $(e.target);
    const parent = $e.parents(".tag-relationship");
    const route = parent.data("relationship-route");
    const human = parent.data("relationship-human");
    const id = parent.data("relationship-id");

    if (!confirm(`Are you sure you want to approve this ${human}?`)) {
      return;
    }

    $.ajax({
      url: `/${route}/${id}/approve.json`,
      type: "POST",
      dataType: "json",
    }).done(function () {
      E621.Toast.notice(`Accepted ${human}.`);
      parent.slideUp("fast");
    }).fail(function () {
      E621.Toast.alert(`Failed to accept ${human}.`);
    });
  }

  static reject (e) {
    e.preventDefault();
    const $e = $(e.target);
    const parent = $e.parents(".tag-relationship");
    const route = parent.data("relationship-route");
    const human = parent.data("relationship-human");
    const id = parent.data("relationship-id");

    if (!confirm(`Are you sure you want to reject this ${human}?`)) {
      return;
    }

    $.ajax({
      url: `/${route}/${id}.json`,
      type: "DELETE",
      dataType: "json",
    }).done(function () {
      E621.Toast.notice(`Rejected ${human}.`);
      parent.slideUp("fast");
    }).fail(function () {
      E621.Toast.alert(`Failed to reject ${human}.`);
    });
  }

  static undo (e) {
    e.preventDefault();
    const $e = $(e.target);
    const parent = $e.parents(".tag-relationship");
    const route = parent.data("relationship-route");
    const human = parent.data("relationship-human");
    const id = parent.data("relationship-id");
    const postCount = $e.data("undoPostCount");

    if (!confirm(`Are you sure you want to undo this ${human}? This will modify approximately ${postCount} posts.`)) {
      return;
    }

    $.ajax({
      url: `/${route}/${id}/undo.json`,
      type: "POST",
      dataType: "json",
    }).done(function () {
      E621.Toast.notice(`Undo of ${human} queued.`);
    }).fail(function () {
      E621.Toast.alert(`Failed to undo ${human}.`);
    });
  }
}

$(document).ready(function () {
  $(".tag-relationship-accept").on("click", e => {
    TagRelationships.approve(e);
  });
  $(".tag-relationship-reject").on("click", e => {
    TagRelationships.reject(e);
  });
  $(".tag-relationship-undo").on("click", e => {
    TagRelationships.undo(e);
  });
});

export default TagRelationships;
