/** @module TextPost Contains utilities for handling text posts (e.g. comments, forum posts, blips). */

/** Contains utilities for handling text posts (e.g. comments, forum posts, blips). */
const TextPost = Object.freeze(
  {
    /**
     * Pulls the raw URL to the post from the post's UI. Using this method preserves the behavior of
     * forum posts linking to the post's anchor on its forum topic's page, comments linking to the
     * comment's anchor on its post's page, & blips linking directly to the blip's page.
     * @param {JQuery<HTMLElement> | HTMLElement} postElement The post to pull the URL from
     * @returns {String} The raw URL as contained in the anchor (won't include the domain, will
     * include path, query, & fragment).
     */
    retrieveOwnUrlSegment (postElement) {
      if (postElement instanceof HTMLElement) { postElement = $(postElement); }
      return postElement.find(".post-time a").attr("href");
    },
  },
);

export default TextPost;
