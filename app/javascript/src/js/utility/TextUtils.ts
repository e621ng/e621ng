export default class TextUtils {

  /**
   * @returns {boolean} True if the Clipboard API is supported, false otherwise
   */
  static get clipboardSupported (): boolean {
    return !!navigator.clipboard;
  }

  /**
   * Copy the given text to the clipboard using the Clipboard API.
   * @param text The text to copy to the clipboard
   * @returns Promise that resolves when the text has been copied, or rejects if the Clipboard API is not supported
   */
  static async copyToClipboard (text: string) {
    if (!TextUtils.clipboardSupported)
      return Promise.reject(new Error("Clipboard API not supported"));
    return navigator.clipboard.writeText(text);
  }

  // https://regex101.com/r/1kVuT1/
  private static quoteRegex = /\[quote\](?!\[quote\])(?:[\S\s](?!\[quote\]))*?\[\/quote\][\n\r]*/sg;

  /**
   * Recursively remove all quoted text blocks from the message.
   * To avoid broken DText resulting from multi-layered quote blocks, we remove
   * the innermost quotes one at a time until there are none left.
   * @param {String} string Input message
   * @returns {String} Output message with quotes removed
   */
  static stripQuotes (string: string): string {
    do {
      string = string.replace(TextUtils.quoteRegex, "");
    } while (TextUtils.quoteRegex.test(string));
    return string;
  }

  /**
   * Format a quoted message for display.
   * @param {String} message The message to quote
   * @param {String} creatorName Username of the message creator
   * @param {Number} creatorId ID of the message creator
   * @returns {String} The formatted quote
   */
  static formatQuote (message: string, creatorName: string, creatorId: number): string {
    return `[quote]"${creatorName}":/users/${creatorId} said:\n${TextUtils.stripQuotes(message)}\n[/quote]\n\n`;
  }

  /**
   * Process a quoted message and insert it into the textarea.
   * @param {jQuery<HTMLInputElement>} $textarea The textarea element
   * @param {String} quotedText The message to quote
   * @param {String} creatorName Username of the message creator
   * @param {Number} creatorId ID of the message creator
   */
  static processQuote ($textarea: JQuery<HTMLInputElement>, quotedText: string, creatorName: string, creatorId: number): void {
    let message = TextUtils.formatQuote(quotedText, creatorName, creatorId);

    const existingInput = $textarea.val() + "";
    if (existingInput.length > 0)
      message = existingInput + (existingInput.endsWith("\n\n") ? "" : "\n\n") + message;
    $textarea.val(message);
  }
}
