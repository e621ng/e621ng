/**
 * Downscale an image File to a small JPEG for the IQDB similarity check.
 * IQDB only uses a ~128px thumbnail, so shipping the original multi-MB file
 * (which gets uploaded again on submit) is pure waste.
 *
 * Resolves to the original File on any failure (decode, canvas, toBlob) —
 * the server thumbnails whatever it receives, so the caller never needs a
 * try/catch.
 */

export async function downscaleImage (file: File, maxDim = 300): Promise<Blob> {
  try {
    const source = await decode(file);
    const scale = Math.min(1, maxDim / Math.max(source.width, source.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(source.width * scale));
    canvas.height = Math.max(1, Math.round(source.height * scale));

    const ctx = canvas.getContext("2d");
    if (!ctx) return file;
    ctx.drawImage(source.image, 0, 0, canvas.width, canvas.height);
    source.close();

    const blob = await new Promise<Blob | null>(resolve => canvas.toBlob(resolve, "image/jpeg", 0.8));
    return blob ?? file;
  } catch {
    return file;
  }
}

interface DecodedImage {
  image: CanvasImageSource;
  width: number;
  height: number;
  close: () => void;
}

async function decode (file: File): Promise<DecodedImage> {
  try {
    const bitmap = await createImageBitmap(file);
    return { image: bitmap, width: bitmap.width, height: bitmap.height, close: () => bitmap.close() };
  } catch {
    return decodeViaImage(file);
  }
}

function decodeViaImage (file: File): Promise<DecodedImage> {
  const objectUrl = URL.createObjectURL(file);
  return new Promise<DecodedImage>((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve({ image: img, width: img.naturalWidth, height: img.naturalHeight, close: () => {} });
    img.onerror = () => reject(new Error("decode failed"));
    img.src = objectUrl;
  }).finally(() => URL.revokeObjectURL(objectUrl));
}
