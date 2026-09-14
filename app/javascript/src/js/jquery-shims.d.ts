// jQuery is injected as globals ($ / jQuery) by @rollup/plugin-inject at build
// time (vite.config.mts), so legacy sources use them without importing. The
// type-checker sees neither the inject plugin nor an import; this reference
// pulls @types/jquery's ambient globals ($, jQuery, JQuery, JQueryStatic) into
// the program.
/// <reference types="jquery" />
