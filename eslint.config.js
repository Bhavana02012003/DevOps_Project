import js from "@eslint/js";
import lwc from "@lwc/eslint-plugin-lwc";
import aura from "@salesforce/eslint-plugin-aura";
import lightning from "@salesforce/eslint-plugin-lightning";
import importPlugin from "eslint-plugin-import";
import jest from "eslint-plugin-jest";

export default [
  // Base JS recommended rules
  js.configs.recommended,

  // -----------------------------
  // ✅ LWC + Aura JS (controllers/helpers/components)
  // -----------------------------
  {
    files: ["**/{lwc,aura}/**/*.js", "temp_scanner_files/**/*.js"],
    plugins: {
      "@lwc/lwc": lwc,
      "@salesforce/aura": aura,
      "@salesforce/lightning": lightning,
      import: importPlugin,
      jest: jest,
    },
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: "module",
    },
    rules: {
      "no-console": ["error", { allow: ["warn", "error"] }],
      "no-debugger": "error",
      "no-unused-vars": "warn",
      "no-undef": "error",
      eqeqeq: ["error", "always"],
      curly: "error",
      semi: ["error", "always"],

      "@lwc/lwc/no-async-await-in-wire": "error",
      "@lwc/lwc/no-deprecated": "warn",
      "@lwc/lwc/no-inner-html": "error",
      "@lwc/lwc/no-dupe-class-members": "error",
    },
  },

  // -----------------------------
  // ✅ LWC HTML templates
  // IMPORTANT: This processor is what prevents "UnknownRule" parsing errors
  // -----------------------------
  {
    files: ["**/lwc/**/*.html", "temp_scanner_files/**/*.html"],
    plugins: {
      "@lwc/lwc": lwc,
    },
    processor: lwc.processors[".html"],
    rules: {
      // You can keep this empty or add template rules later
    },
  },
];