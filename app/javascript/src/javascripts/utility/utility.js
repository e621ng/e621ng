let Utility = {};

Utility.delay = function (milliseconds) {
  return new Promise(resolve => setTimeout(resolve, milliseconds));
};

Utility.meta = function (key) {
  return $("meta[name=" + key + "]").attr("content");
};

Utility.test_max_width = function (width) {
  if (!window.matchMedia) {
    return false;
  }
  var mq = window.matchMedia("(max-width: " + width + "px)");
  return mq.matches;
};

Utility.notice_timeout_id = undefined;

Utility.notice = function (msg, permanent) {
  $("#notice").addClass("ui-state-highlight").removeClass("ui-state-error").fadeIn("fast").children("span").html(msg);

  if (Utility.notice_timeout_id !== undefined) {
    clearTimeout(Utility.notice_timeout_id);
  }
  if (!permanent) {
    Utility.notice_timeout_id = setTimeout(function () {
      $("#close-notice-link").click();
      Utility.notice_timeout_id = undefined;
    }, 3000);
  }
};

Utility.error = function (msg) {
  $("#notice").removeClass("ui-state-highlight").addClass("ui-state-error").fadeIn("fast").children("span").html(msg);

  if (Utility.notice_timeout_id !== undefined) {
    clearTimeout(Utility.notice_timeout_id);
  }
};

Utility.is_subset = function (array, subarray) {
  var all = true;

  $.each(subarray, function (i, val) {
    if ($.inArray(val, array) === -1) {
      all = false;
    }
  });

  return all;
};

Utility.intersect = function (a, b) {
  a = a.slice(0).sort();
  b = b.slice(0).sort();
  var result = [];
  while (a.length > 0 && b.length > 0) {
    if (a[0] < b[0]) {
      a.shift();
    } else if (a[0] > b[0]) {
      b.shift();
    } else {
      result.push(a.shift());
      b.shift();
    }
  }
  return result;
};

Utility.regexp_escape = function (string) {
  return string.replace(/([.?*+^$[\]\\(){}|-])/g, "\\$1");
};

/**
 * An analogue for Rails' `blank?` method.
 * @param {*} o The object to check.
 * @returns `true` for `undefined`, `string`s that are empty or contain only whitespace, and
 * `object`s that are falsy, have no `length` property, or a `length` property with a value of `0`.
 */
Utility.blank = function (o) {
  switch (typeof o) {
    case "undefined":
      return true;
    case "string":
      return o.trim().length <= 0;
    case "object":
      return !o || !o.length;
    default:
      return false;
  }
};

$.fn.selectEnd = function () {
  return this.each(function () {
    this.focus();
    this.setSelectionRange(this.value.length, this.value.length);
  });
};

$(function () {
  $(window).on("danbooru:notice", function (event, msg) {
    Utility.notice(msg);
  });

  $(window).on("danbooru:error", function (event, msg) {
    Utility.error(msg);
  });
});

export default Utility;
