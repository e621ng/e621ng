const TextUtils = {};

// https://regex101.com/r/1kVuT1/
TextUtils._quoteRegex = /\[quote\](?!\[quote\])(?:[\S\s](?!\[quote\]))*?\[\/quote\][\n\r]*/sg;

/**
 * Recursively remove all quoted text blocks from the message.
 * To avoid broken DText resulting from multi-layered quote blocks, we remove
 * the innermost quotes one at a time until there are none left.
 * @param {String} string Input message
 * @returns {String} Output message with quotes removed
 */
TextUtils.strip_quotes = function (string) {
  do {
    string = string.replaceAll(TextUtils._quoteRegex, "");
  } while (TextUtils._quoteRegex.test(string));
  return string;
};

/**
 * Format a quoted message for display.
 * @param {String} message The message to quote
 * @param {String} creatorName Username of the message creator
 * @param {Number} creatorId ID of the message creator
 * @returns {String} The formatted quote
 */
TextUtils.formatQuote = function (message, creatorName, creatorId) {
  return `[quote]"${creatorName}":/users/${creatorId} said:\n${TextUtils.strip_quotes(message)}\n[/quote]\n\n`;
};

/**
 * Process a quoted message and insert it into the textarea.
 * @param {jQuery<HTMLInputElement>} $textarea The textarea element
 * @param {String} quotedText The message to quote
 * @param {String} creatorName Username of the message creator
 * @param {Number} creatorId ID of the message creator
 */
TextUtils.processQuote = function ($textarea, quotedText, creatorName, creatorId) {
  let message = TextUtils.formatQuote(quotedText, creatorName, creatorId);

  const existingInput = $textarea.val();
  if (existingInput.length > 0)
    message = existingInput + (existingInput.endsWith("\n\n") ? "" : "\n\n") + message;
  $textarea.val(message);
};

export default TextUtils;
