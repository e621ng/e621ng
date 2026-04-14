/**
 * GenInfo Extractor
 *
 * Extracts generation parameters from image files:
 * - PNG: tEXt chunks (pnginfo)
 * - JPEG: EXIF UserComment (piexif unicode encoding)
 *
 * Uses HTTP Range requests to fetch only the header portion of the file.
 */

const GenInfo = {};

// Maximum bytes to fetch (32KB should cover metadata before image data)
const MAX_FETCH_BYTES = 32 * 1024;

// PNG signature: 0x89 P N G \r \n 0x1A \n
const PNG_SIGNATURE = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

// EXIF constants
const EXIF_IFD_TAG = 0x8769;
const USER_COMMENT_TAG = 0x9286;

/**
 * Parse PNG chunks from an ArrayBuffer
 * Stops when it hits IDAT (image data) since metadata comes before that
 */
GenInfo.parsePngChunks = function (buffer) {
  const view = new DataView(buffer);
  const chunks = [];

  // Verify PNG signature
  for (let i = 0; i < PNG_SIGNATURE.length; i++) {
    if (view.getUint8(i) !== PNG_SIGNATURE[i]) {
      throw new Error("Not a valid PNG file");
    }
  }

  let offset = 8; // Skip signature

  while (offset < buffer.byteLength - 12) { // Need at least 12 bytes for a chunk
    const length = view.getUint32(offset);
    const typeBytes = new Uint8Array(buffer, offset + 4, 4);
    const type = String.fromCharCode(...typeBytes);

    // Stop at IDAT - we've got all the metadata
    if (type === "IDAT") {
      break;
    }

    // Extract tEXt chunks
    if (type === "tEXt") {
      const data = new Uint8Array(buffer, offset + 8, Math.min(length, buffer.byteLength - offset - 12));
      const nullIndex = data.indexOf(0);
      if (nullIndex !== -1) {
        chunks.push({
          keyword: GenInfo.decodeText(data.slice(0, nullIndex)),
          text: GenInfo.decodeText(data.slice(nullIndex + 1)),
        });
      }
    }

    // Move to next chunk: 4 (length) + 4 (type) + length (data) + 4 (CRC)
    offset += 12 + length;
  }

  return chunks;
};

/**
 * Parse JPEG EXIF UserComment from an ArrayBuffer.
 * Follows the same approach as piexif: find APP1, walk IFD0 -> ExifIFD -> UserComment.
 * Returns chunks array compatible with PNG output format.
 */
GenInfo.parseJpegUserComment = function (buffer) {
  const view = new DataView(buffer);

  // Verify JPEG SOI marker
  if (view.getUint16(0) !== 0xFFD8) {
    throw new Error("Not a valid JPEG file");
  }

  // Find APP1 (Exif) marker
  let offset = 2;
  while (offset < buffer.byteLength - 4) {
    const marker = view.getUint16(offset);
    if (marker === 0xFFE1) {
      const segmentLength = view.getUint16(offset + 2);
      const segmentStart = offset + 4;

      // Check for "Exif\0\0" header
      if (
        view.getUint32(segmentStart) === 0x45786966 // "Exif"
        && view.getUint16(segmentStart + 4) === 0x0000
      ) {
        return GenInfo.parseExifUserComment(buffer, segmentStart + 6, segmentLength - 2);
      }
    }

    // Not APP1 or not Exif — skip this segment
    if ((marker & 0xFF00) !== 0xFF00) break; // Not a valid marker
    const len = view.getUint16(offset + 2);
    offset += 2 + len;
  }

  return [];
};

/**
 * Parse EXIF IFDs to extract UserComment.
 * tiffStart is the absolute offset of the TIFF header ("II" or "MM") in the buffer.
 */
GenInfo.parseExifUserComment = function (buffer, tiffStart) {
  const view = new DataView(buffer);

  // Read byte order
  const byteOrder = view.getUint16(tiffStart);
  const le = byteOrder === 0x4949; // "II" = little-endian

  const getU16 = (off) => view.getUint16(tiffStart + off, le);
  const getU32 = (off) => view.getUint32(tiffStart + off, le);

  // IFD0 offset (from TIFF header)
  const ifd0Offset = getU32(4);

  // Walk IFD0 to find ExifIFD pointer
  const ifd0Entries = getU16(ifd0Offset);
  let exifIfdOffset = null;
  for (let i = 0; i < ifd0Entries; i++) {
    const entryOff = ifd0Offset + 2 + (i * 12);
    if (getU16(entryOff) === EXIF_IFD_TAG) {
      exifIfdOffset = getU32(entryOff + 8);
      break;
    }
  }

  if (exifIfdOffset === null) return [];

  // Walk ExifIFD to find UserComment
  const exifEntries = getU16(exifIfdOffset);
  for (let i = 0; i < exifEntries; i++) {
    const entryOff = exifIfdOffset + 2 + (i * 12);
    if (getU16(entryOff) === USER_COMMENT_TAG) {
      const count = getU32(entryOff + 4);
      // Value offset (UNDEFINED type, count > 4 means offset is stored)
      const valueOffset = count > 4 ? getU32(entryOff + 8) : entryOff + 8;
      const commentBytes = new Uint8Array(buffer, tiffStart + valueOffset, Math.min(count, buffer.byteLength - tiffStart - valueOffset));

      // First 8 bytes are charset identifier
      const charset = String.fromCharCode(...commentBytes.slice(0, 8)).replace(/\0/g, "");
      const payload = commentBytes.slice(8);

      let text;
      if (charset === "UNICODE") {
        text = new TextDecoder("utf-16be").decode(payload);
      } else {
        text = GenInfo.decodeText(payload);
      }

      if (text) {
        return [{ keyword: "parameters", text }];
      }
    }
  }

  return [];
};

/**
 * Decode bytes to string
 */
GenInfo.decodeText = function (bytes) {
  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    return new TextDecoder("latin1").decode(bytes);
  }
};

/**
 * Fetch image metadata using Range request
 */
GenInfo.fetchMetadata = async function (url, fileExt) {
  const response = await fetch(url, {
    headers: {
      "Range": `bytes=0-${MAX_FETCH_BYTES - 1}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch: ${response.status}`);
  }

  const buffer = await response.arrayBuffer();

  if (fileExt === "png") {
    return GenInfo.parsePngChunks(buffer);
  }
  return GenInfo.parseJpegUserComment(buffer);
};

/**
 * Render metadata chunks to HTML
 */
GenInfo.renderMetadata = function (chunks) {
  if (!chunks || chunks.length === 0) return null;

  const $details = $("<details>").attr("id", "gen-info");
  $details.append($("<summary>").text("Generation Info"));

  const $content = $("<div>").addClass("gen-info-content");

  chunks.forEach(chunk => {
    const $item = $("<div>").addClass("gen-info-item");
    $item.append($("<div>").addClass("gen-info-key").text(chunk.keyword));
    $item.append($("<code>").addClass("gen-info-value").text(chunk.text));
    $content.append($item);
  });

  $details.append($content);
  return $details;
};

/**
 * Get the original file URL and extension (handle sample URL rewriting)
 */
GenInfo.getOriginalUrl = function () {
  const $container = $("#image-container");
  if (!$container.length) return null;

  const fileExt = $container.data("file-ext");
  if (!["png", "jpg", "jpeg"].includes(fileExt)) return null;

  const postData = $container.data("post");
  const url = postData?.file?.url || null;
  if (!url) return null;

  return { url, fileExt };
};

/**
 * Fetch and render metadata, inserting it into the page.
 * Returns true if metadata was found, false otherwise.
 */
GenInfo.loadAndShow = async function () {
  const result = GenInfo.getOriginalUrl();
  if (!result) return false;

  const $container = $("#gen-info-container");
  if (!$container.length) return false;

  const chunks = await GenInfo.fetchMetadata(result.url, result.fileExt);
  const $element = GenInfo.renderMetadata(chunks);

  if ($element) {
    $container.append($element);
    $element.attr("open", true);
    return true;
  }

  const $details = $("<details>")
    .attr({
      "id": "gen-info",
      "open": true,
    })
    .appendTo($container);
  $("<summary>").text("Generation Info").appendTo($details);
  $("<span>").text("No generation info found.").appendTo($details);
  return false;
};

export default GenInfo;
