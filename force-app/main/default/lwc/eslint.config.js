export default [
    {
      ignores: ["node_modules", "dist"],  // ✅ Replaces `.eslintignore`
      rules: {
        "no-console": ["error", { "allow": ["warn", "error"] }],
        "no-debugger": "error",
        "no-unused-vars": "warn",
        "no-undef": "error",
        "eqeqeq": ["error", "always"],
        "curly": "error",
        "semi": ["error", "always"],
        "@salesforce/lwc/no-unexpected-wire-adapter-usages": "error",
        "@salesforce/lwc/no-async-await-in-wire": "error",
        "@salesforce/lwc/valid-wire": "error",
        "@salesforce/lwc/no-deprecated": "warn",
        "@salesforce/lwc/no-dupe-class-members": "error",
        "@salesforce/lwc/no-document-query": "warn",
        "@salesforce/lwc/no-inner-html": "error",
        "@salesforce/lwc/no-direct-document-query": "error"
      }
    }
  ];
  