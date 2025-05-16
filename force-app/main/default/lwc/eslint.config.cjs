const lwcPlugin = require("@lwc/eslint-plugin-lwc").default || require("@lwc/eslint-plugin-lwc");

module.exports = [
  {
    ignores: ["node_modules/", "dist/", "coverage/"], // ✅ Replaces .eslintignore
  },
  {
    plugins: {
      "@lwc": lwcPlugin, // ✅ Correctly requires the LWC plugin
    },
    rules: {
      "@lwc/no-unexpected-wire-adapter-usages": "error",
      "@lwc/no-async-await-in-wire": "error",
      "@lwc/valid-wire": "error",
      "@lwc/no-deprecated": "warn",
      "@lwc/no-dupe-class-members": "error",
      "@lwc/no-document-query": "warn",
      "@lwc/no-inner-html": "error",
      "@lwc/no-direct-document-query": "error",
      "no-console": ["error", { "allow": ["warn", "error"] }],
      "no-debugger": "error",
      "no-unused-vars": "warn",
      "no-undef": "error",
      "eqeqeq": ["error", "always"],
      "curly": "error",
      "semi": ["error", "always"],
    },
  },
];
