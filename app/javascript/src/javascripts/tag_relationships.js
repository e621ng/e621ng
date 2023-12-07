import Utility from './utility.js';

class TagRelationships {
  static approve(e) {
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
      type: 'POST',
      dataType: 'json'
    }).done(function (data) {
      Utility.notice(`Accepted ${human}.`);
      parent.slideUp('fast');
    }).fail(function (data) {
      Utility.error(`Failed to accept ${human}.`);
    });
  }

  static reject(e) {
    e.preventDefault();
    const $e = $(e.target);
    const parent = $e.parents(".tag-relationship");
    const route = parent.data("relationship-route");
    const human = parent.data("relationship-human");
    const id = parent.data("relationship-id");

    if(!confirm(`Are you sure you want to reject this ${human}?`)) {
      return;
    }

    $.ajax({
      url: `/${route}/${id}.json`,
      type: 'DELETE',
      dataType: 'json'
    }).done(function (data) {
      Utility.notice(`Rejected ${human}.`);
      parent.slideUp('fast');
    }).fail(function (data) {
      Utility.error(`Failed to reject ${human}.`);
    });
  }
}

$(document).ready(function() {
  $(".tag-relationship-accept").on('click', e => {
    TagRelationships.approve(e);
  });
  $(".tag-relationship-reject").on('click', e => {
    TagRelationships.reject(e);
  });
});

export default TagRelationships
