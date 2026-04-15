// Stub for rrweb. The @openpanel/web package statically imports `record` from
// rrweb even when session replay is disabled. This stub replaces the module so
// that rrweb is not included in the bundle. See: https://github.com/Openpanel-dev/openpanel/issues/336
export function record () { return () => {}; }
