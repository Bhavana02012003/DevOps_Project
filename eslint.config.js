// No imports on purpose to avoid package resolution.
// Core rules only.
export default [{
  files: ["**/*.js", "**/*.jsx"],
  ignores: ["dist/**", "build/**", "coverage/**", "node_modules/**"],
  languageOptions: {
    ecmaVersion: "latest",
    sourceType: "module",
  },
  rules: {
    "no-undef": "error",
    "no-unused-vars": ["error", { "argsIgnorePattern": "^_" }],
    "no-console": "warn",
    "eqeqeq": "error",
    "curly": "error"
  }
}];
