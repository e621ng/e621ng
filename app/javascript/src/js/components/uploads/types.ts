export interface PreviewData {
  url: string;
  isVideo: boolean;
}

// Payload of file_input's "change" event: the current value (URL string or a
// picked File), its preview, and whether it's currently invalid.
export interface UploadChange {
  value: string | File;
  preview: PreviewData;
  invalid: boolean;
}
