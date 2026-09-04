import HTTP from "./HTTP";

/**
 * Classified outcome of an upload-style form POST. Callers branch on `kind`:
 * - success: 2xx with a JSON body
 * - blocked: Cloudflare challenge/403 — `message` is ready to display
 * - error:   a JSON error body — caller maps `json` to its own message
 * - failed:  non-JSON error body or network failure — generic `message` ready
 */
export type SubmitOutcome
  = { kind: "success", body: any }
  | { kind: "blocked", message: string }
  | { kind: "error", json: any }
  | { kind: "failed", message: string };

const GENERIC_FAILURE = "Error: The upload could not be completed. Check the browser console for details.";

/**
 * POST a FormData payload and classify the response. Shared by the uploader and
 * the replacement uploader so their transport/error handling can't drift apart.
 */
export async function submitUploadForm (url: string, formData: FormData): Promise<SubmitOutcome> {
  try {
    const response = await HTTP.request(url, { method: "POST", body: formData });

    if (response.ok)
      return { kind: "success", body: await response.json() };

    // A Cloudflare-mitigated challenge is the one header signal only CF itself
    // produces — safe to trust before looking at the body.
    const cfMitigated = (response.headers.get("cf-mitigated") || "").trim().toLowerCase();
    if (cfMitigated.includes("challenge"))
      return { kind: "blocked", message: "Error: The upload was blocked by a security challenge. Please try again in a moment." };

    // Parse before blaming Cloudflare: behind CF every response — origin 403s
    // included — carries server:cloudflare + cf-ray, so those headers alone prove
    // nothing. An origin error on a .json endpoint always ships a JSON body; a
    // CF-generated block page is HTML.
    let json: any;
    try {
      json = await response.json();
    } catch {
      const cfRay = response.headers.get("cf-ray");
      const serverHeader = (response.headers.get("server") || "").trim().toLowerCase();
      if (response.status === 403 && (serverHeader.includes("cloudflare") || !!cfRay))
        return { kind: "blocked", message: "Error: The upload was blocked by Cloudflare (403). Please try again in a moment." };
      return { kind: "failed", message: GENERIC_FAILURE };
    }
    return { kind: "error", json };
  } catch (error) {
    console.error("Error submitting upload:", error);
    return { kind: "failed", message: GENERIC_FAILURE };
  }
}
