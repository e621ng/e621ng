/** Validation rules for the source field of the post edit form. */

export function splitUrls (text: string | null | undefined): string[] {
  return text?.split(/\r?\n/) || [];
}

export function isUrlValid (url: string, ignore: string[] = []): boolean {
  url = url.trim();
  if (url.length <= 0) return true;
  // So existing invalid source links are skipped
  if (ignore.includes(url)) return true;
  // Allow dead source links prefixed with `-`
  if (url[0] === "-") url = url.substring(1);
  try {
    const parsed = new URL(url);
    return parsed.protocol === "http:" || parsed.protocol === "https:";
  } catch {
    // The URL constructor throws on anything that is not a valid URL
    return false;
  }
}

export function allUrlsValid (urls: string[], ignore: string[] = []): boolean {
  return urls.every((url) => isUrlValid(url, ignore));
}
