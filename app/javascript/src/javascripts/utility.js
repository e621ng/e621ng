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

/**
 * @type {Function}
 */
Utility.regexp_escape = RegExp.escape || function (string) {
  return string.replace(/([.?*+^$[\]\\(){}|-])/g, "\\$1");
};

/**
 * An analog for the Rails [`blank?`](<https://apidock.com/rails/Object/blank%3F>) method.
 * @param {any} e The object to check.
 * @returns `true` if the object is `null`, `undefined`, an `Array`/`string`(/object with a `length`
 * property) that has 0 elements, or a `string` of only whitespace characters; `false` otherwise.
 */
Utility.isBlank = function (e) {
  return e === undefined || e === null || (e.length !== undefined && (e.length === 0 || (typeof(e) === "string" && e.trim().length === 0)));
};

/**
 * An analog for the Rails [`present?`](<https://apidock.com/rails/Object/present%3F>) method.
 * @param {any} e The object to check.
 * @returns `true` if the object is not blank (see `isBlank`); `false` otherwise.
 */
Utility.isPresent = (e) => !Utility.isBlank(e);

/**
 * An analog for the Rails [`presence`](<https://apidock.com/rails/Object/presence>) method.
 * @param {any} e The object to check.
 * @returns The object if it's not blank (see `isBlank`); `undefined` otherwise.
 */
Utility.presence = (e) => Utility.isPresent(e) ? e : undefined;

/**
 * Validates that a text input element expecting an id that receives a URL has its value replaced
 * with the URL's id (should an appropriate one exist).
 *
 * Register on `blur` or `focusout` on an element that has a `id-input` class (or contains applicable
 * elements if delegating).
 *
 * Use the `id-type` attribute to accept only ids for the given resource.
 *
 * Use the `multi-value` attribute to accept more than 1 value:
 * * `comma`: corrects to a comma-separated list
 * * `space`: corrects to a space-separated list
 *
 * Example:
 * ```erb
 * <%= f.input :post_ids_string, as: :text, label: "Posts", input_html: { class: "id-input", "multi-value" => "space" } %>
 * ```
 * @param {FocusEvent} event The event.
 */ //IDEA: Leverage [HTML's `pattern` attribute](<https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/pattern>)?
Utility.validateIdInput = function (event) {
  /** @type {HTMLInputElement|HTMLTextAreaElement} */
  const e = event.target;
  e.classList.remove("invalid-input");
  // If it's not an applicable element or is properly formatted or is permissibly omitted, abort.
  if (
    !(e instanceof HTMLInputElement || e instanceof HTMLTextAreaElement) ||
    !e.classList.contains("id-input") ||
    /^[0-9]+$/.test(e.value) ||
    (e.getAttribute("multi-value") == "space" && /^[0-9 ]+$/.test(e.value)) ||
    (e.getAttribute("multi-value") == "comma" && /^[0-9,]+$/.test(e.value)) ||
    ((e.value?.length || 0) === 0 && !e.hasAttribute("required"))) {
    return;
  }
  // If there's only non-numeric characters in the input, mark invalid & abort.
  if (/^[^0-9]*$/.test(e.value)) {
    e.className += " invalid-input";
    e.value = "";
    return;
  }
  let s0 = `(?:https?://)(?:www\\.)?${Utility.regexp_escape(window.location.host)}/`, s1, s2;
  switch (e.getAttribute("id-type")) {
    case "post":
      s1 = "posts?";
      s2 = "post";
      break;
    case "comment":
      s1 = "comments?";
      s2 = "comment";
      break;
    case "forum_post":
      // TODO: Account for other valid paths.
      s1 = "forum_posts?";
      s2 = "forum_post";
      break;
  
    default:
      s1 = "[^0-9]*"
      s2 = "[^-0-9]*"
      break;
  }
  if (e.hasAttribute("multi-value")) {
    const initialV = e.value;
    const re = RegExp(`${s0}(?:${s1}/([0-9]+)|.+?${s2}-([0-9]+))`, "g");
    let values = [];
    e.value = "";
    for (let match = re.exec(initialV); match; match = re.exec(initialV)) {
      values.push(Utility.presence(match[1]) || match[2]);
    }
    e.value = values.join(e.getAttribute("multi-value") == "space" ? " " : ",");
    if (Utility.isBlank(e.value) && e.hasAttribute("required")) {
      e.className += " invalid-input";
    }
  } else {
    const match = RegExp(
      `${s0}(?:${s1}/([0-9]+)|.+?${s2}-([0-9]+))`,
      e.hasAttribute("multi-value") ? "g" : undefined,
    ).exec(e.value);
    if (!match) {
      e.value = "";
      if (e.hasAttribute("required"))
        e.className += " invalid-input";
      return;
    }
    e.value = Utility.presence(match[1]) || match[2];
  }
};

$.fn.selectEnd = function () {
  return this.each(function () {
    this.focus();
    this.setSelectionRange(this.value.length, this.value.length);
  });
};

$(function () {
  $('.id-input').on("focusout", Utility.validateIdInput);

  $(window).on("danbooru:notice", function (event, msg) {
    Utility.notice(msg);
  });

  $(window).on("danbooru:error", function (event, msg) {
    Utility.error(msg);
  });
});

export default Utility;
