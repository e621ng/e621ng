import globals from "globals";
import eslint from "@eslint/js";
import stylistic from "@stylistic/eslint-plugin";
import tseslint from "typescript-eslint";

const sharedLanguageOptions = {
  ecmaVersion: "latest",
  globals: {
    ...globals.browser,
    $: false,
    Danbooru: false,
    E621: false,
  },
};

const sharedPlugins = {
  "@stylistic": stylistic,
};

// https://eslint.style/packages/js
const sharedRules = {
  "@stylistic/array-bracket-newline": "warn",
  "@stylistic/array-bracket-spacing": "off",
  "@stylistic/array-element-newline": ["warn", "consistent"],
  "@stylistic/arrow-parens": "off",
  "@stylistic/arrow-spacing": "warn",
  "@stylistic/block-spacing": "warn",
  "@stylistic/brace-style": ["warn", "1tbs", { allowSingleLine: true }],
  "@stylistic/comma-dangle": ["warn", "always-multiline"],
  "@stylistic/comma-spacing": "warn",
  "@stylistic/comma-style": "warn",
  "@stylistic/computed-property-spacing": "warn",
  "@stylistic/dot-location": ["warn", "property"],
  "@stylistic/eol-last": "warn",
  "@stylistic/function-call-argument-newline": ["warn", "consistent"],
  "@stylistic/function-call-spacing": "warn",
  "@stylistic/implicit-arrow-linebreak": "warn",
  "@stylistic/indent": ["warn", 2, { SwitchCase: 1, }],
  "@stylistic/key-spacing": ["warn", { mode: "minimum" }],
  "@stylistic/keyword-spacing": "warn",
  "@stylistic/line-comment-position": "off",
  "@stylistic/linebreak-style": "error",
  "@stylistic/lines-around-comment": "off",
  "@stylistic/lines-between-class-members": ["warn", "always", { exceptAfterSingleLine: true }],
  // "@stylistic/max-len": ["warn", { code: 100, tabWidth: 2, ignoreComments: true }], // Might get annoying, see https://eslint.style/rules/js/max-len
  "@stylistic/max-statements-per-line": ["warn", { "max": 2 }],
  "@stylistic/multiline-comment-style": "off",
  "@stylistic/multiline-ternary": ["warn", "always-multiline"],
  "@stylistic/new-parens": "warn",
  "@stylistic/newline-per-chained-call": "off",
  "@stylistic/no-confusing-arrow": "warn",
  "@stylistic/no-extra-parens": "off",
  "@stylistic/no-extra-semi": "warn",
  "@stylistic/no-floating-decimal": "warn",
  "@stylistic/no-mixed-operators": "error",
  "@stylistic/no-mixed-spaces-and-tabs": "error",
  "@stylistic/no-multi-spaces": ["warn", { ignoreEOLComments: true }],
  "@stylistic/no-multiple-empty-lines": "warn",
  "@stylistic/no-tabs": "warn",
  "@stylistic/no-trailing-spaces": ["warn", { ignoreComments: true, }],
  "@stylistic/no-whitespace-before-property": "warn",
  "@stylistic/nonblock-statement-body-position": "off",
  "@stylistic/object-curly-newline": ["warn", { consistent: true }],
  "@stylistic/one-var-declaration-per-line": "off",
  "@stylistic/operator-linebreak": ["warn", "before"],
  "@stylistic/padded-blocks": "off",
  "@stylistic/padding-line-between-statements": "off",
  "@stylistic/quote-props": ["warn", "consistent"],
  "@stylistic/quotes": ["warn", "double", { avoidEscape: true }],
  "@stylistic/rest-spread-spacing": "warn",
  "@stylistic/semi": "warn",
  "@stylistic/semi-spacing": "warn",
  "@stylistic/semi-style": "warn",
  "@stylistic/space-before-blocks": "warn",
  "@stylistic/space-before-function-paren": "warn", // good idea?
  "@stylistic/space-in-parens": "warn",
  "@stylistic/space-infix-ops": "warn",
  "@stylistic/space-unary-ops": "warn",
  "@stylistic/spaced-comment": "warn",
  "@stylistic/switch-colon-spacing": "warn",
  "@stylistic/template-curly-spacing": "warn",
  "@stylistic/template-tag-spacing": "warn",
};

export default [
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["**/*.ts"],
    languageOptions: sharedLanguageOptions,
    plugins: sharedPlugins,
    rules: {
      // Disable base rules that have TS-aware equivalents
      "no-unused-vars": "off",
      "@typescript-eslint/no-unused-vars": ["warn", { "caughtErrorsIgnorePattern": "^_", "argsIgnorePattern": "^_" }],

      // These are stupid and pointless
      "@typescript-eslint/no-explicit-any": "off",

      ...sharedRules,

      // @stylistic/semi handles semicolons for TS; no-extra-semi is redundant
      "@stylistic/no-extra-semi": "off",
    },
  },
  {
    files: ["**/*.js"],
    languageOptions: sharedLanguageOptions,
    plugins: sharedPlugins,
    rules: {
      "no-unused-vars": ["warn", { "caughtErrorsIgnorePattern": "^_" }],

      // Disable duplicate TS rules
      "@typescript-eslint/no-unused-vars": "off",
      "@typescript-eslint/no-unused-expressions": "off",

      ...sharedRules,
    },
  },
]
