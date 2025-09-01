const TextUtils = {};

TextUtils._quoteRegex = /\[quote\](?!\[quote\])(?:[\S\s](?!\[quote\]))*?\[\/quote\][\n\r]+/sg;
TextUtils.strip_quotes = function (string) {
  console.log(0, string);
  let iteration = 0;
  do {
    string = string.replaceAll(TextUtils._quoteRegex, "");
    console.log(iteration++, string);
  } while (TextUtils._quoteRegex.test(string));
  return string;
};

TextUtils.formatQuote = function (message, creatorName, creatorId) {
  return `[quote]"${creatorName}":/users/${creatorId} said:\n${TextUtils.strip_quotes(message)}\n[/quote]\n\n`;
};

TextUtils.processQuote = function($textarea, quotedText, creatorName, creatorId) {
  let message = TextUtils.formatQuote(quotedText, creatorName, creatorId);

  const existingInput = $textarea.val();
  if (existingInput.length > 0)
    message = existingInput + (existingInput.endsWith("\n\n") ? "" : "\n\n") + message;
  $textarea.val(message);
};

export default TextUtils;
