import js from "@eslint/js";
import lwc from "@lwc/eslint-plugin-lwc";
import aura from "@salesforce/eslint-plugin-aura";
import lightning from "@salesforce/eslint-plugin-lightning";
import importPlugin from "eslint-plugin-import";
import jest from "eslint-plugin-jest";

export default [
  // Base JS recommended rules
  js.configs.recommended,

  // ✅ Use the plugin's recommended rules (prevents "rule not found" crashes)
  ...(lwc.configs.recommended ?? []),

  {
    files: ["**/{lwc,aura}/**/*.js", "temp_scanner_files/**/*.js"],
    plugins: {
      "@lwc/lwc": lwc,
      "@salesforce/aura": aura,
      "@salesforce/lightning": lightning,
      import: importPlugin,
      jest: jest
    },
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: "module"
    },
    rules: {
      // ✅ This is the rule that will catch console.log
      "no-console": ["error", { allow: ["warn", "error"] }],
      "no-debugger": "error",
      "no-unused-vars": "warn",
      "no-undef": "error",
      "eqeqeq": ["error", "always"],
      "curly": "error",
      "semi": ["error", "always"]
    }
  },

  // ✅ LWC HTML templates (prevents parsing/UnknownRule errors)
  {
    files: ["**/lwc/**/*.html", "temp_scanner_files/**/*.html"],
    plugins: {
      "@lwc/lwc": lwc
    },
    processor: lwc.processors[".html"],
    rules: {}
  }
];