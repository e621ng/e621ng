import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { downscaleImage } from "@/utility/ImageDownscale";

// jsdom implements neither createImageBitmap nor canvas; both are stubbed.
// What matters here is the contract: a JPEG blob on success, the ORIGINAL
// file on any failure.

const file = new File([new ArrayBuffer(64)], "big.png", { type: "image/png" });
const jpeg = new Blob(["jpeg"], { type: "image/jpeg" });

const bitmap = { width: 1000, height: 500, close: vi.fn() };

beforeEach(() => {
  (globalThis as any).createImageBitmap = vi.fn().mockResolvedValue(bitmap);
  HTMLCanvasElement.prototype.getContext = vi.fn().mockReturnValue({ drawImage: vi.fn() }) as any;
  HTMLCanvasElement.prototype.toBlob = function (cb) { cb(jpeg); };
});
afterEach(() => {
  delete (globalThis as any).createImageBitmap;
  vi.restoreAllMocks();
});

describe("utility/ImageDownscale", () => {
  it("returns the encoded blob and closes the bitmap", async () => {
    expect(await downscaleImage(file)).toBe(jpeg);
    expect(bitmap.close).toHaveBeenCalled();
  });

  // Captures the canvas the helper creates, to assert its dimensions.
  function trackCanvas (): HTMLCanvasElement[] {
    const created: HTMLCanvasElement[] = [];
    const origCreate = document.createElement.bind(document);
    vi.spyOn(document, "createElement").mockImplementation((tag: string) => {
      const el = origCreate(tag);
      if (tag === "canvas") created.push(el as HTMLCanvasElement);
      return el;
    });
    return created;
  }

  it("scales the longer edge down to maxDim", async () => {
    const created = trackCanvas();
    await downscaleImage(file, 300);
    expect(created[0].width).toBe(300);
    expect(created[0].height).toBe(150);
  });

  it("never upscales a small image", async () => {
    (globalThis as any).createImageBitmap = vi.fn().mockResolvedValue({ width: 100, height: 50, close: vi.fn() });
    const created = trackCanvas();
    await downscaleImage(file, 300);
    expect(created[0].width).toBe(100);
    expect(created[0].height).toBe(50);
  });

  it("falls back to the original when the canvas has no 2d context", async () => {
    HTMLCanvasElement.prototype.getContext = vi.fn().mockReturnValue(null) as any;
    expect(await downscaleImage(file)).toBe(file);
  });

  it("falls back to the original when encoding yields no blob", async () => {
    HTMLCanvasElement.prototype.toBlob = function (cb) { cb(null); };
    expect(await downscaleImage(file)).toBe(file);
  });

  it("falls back to the original when decoding fails entirely", async () => {
    (globalThis as any).createImageBitmap = vi.fn().mockRejectedValue(new Error("bad image"));
    // The <img> fallback also fails at object-URL creation.
    vi.spyOn(URL, "createObjectURL").mockImplementation(() => { throw new Error("no blobs"); });
    expect(await downscaleImage(file)).toBe(file);
  });
});
