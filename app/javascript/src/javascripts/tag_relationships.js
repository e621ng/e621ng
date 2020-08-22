import Utility from './utility.js';

class TagRelationships {
  static typePlural(type) {
    if (type === "alias") {
      return "aliases";
    }
    return `${type}s`;
  }
  static approve(e, type) {
    e.preventDefault();
    const $e = $(e.target);
    const parent = $e.parents(`.tag-${type}`)
    const id = parent.data(`${type}-id`);
    $.ajax({
      url: `/tag_${this.typePlural(type)}/${id}/approve.json`,
      type: 'POST',
      dataType: 'json'
    }).done(function (data) {
      Utility.notice(`Accepted ${type}.`);
      parent.slideUp('fast');
    }).fail(function (data) {
      Utility.error(`Failed to accept ${type}.`);
    });
  }

  static reject(e, type) {
    e.preventDefault();
    const $e = $(e.target);
    const parent = $e.parents(`.tag-${type}`)
    const id = parent.data(`${type}-id`);
    if(!confirm(`Are you sure you want to reject this ${type}?`))
      return;
    $.ajax({
      url: `/tag_${this.typePlural(type)}/${id}.json`,
      type: 'DELETE',
      dataType: 'json'
    }).done(function (data) {
      Utility.notice(`Rejected ${type}.`);
      parent.slideUp('fast');
    }).fail(function (data) {
      Utility.error(`Failed to reject ${type}.`);
    });
  }
}

$(document).ready(function() {
  $(".tag-alias-accept").on('click', e => {
    TagRelationships.approve(e, 'alias');
  });
  $(".tag-alias-reject").on('click', e => {
    TagRelationships.reject(e, 'alias');
  });
  $(".tag-implication-accept").on('click', e => {
    TagRelationships.approve(e,'implication');
  });
  $(".tag-implication-reject").on('click', e => {
    TagRelationships.reject(e,'implication');
  })
});

export default TagRelationships
