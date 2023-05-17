/**
 * React Starter Kit (https://www.reactstarterkit.com/)
 *
 * Copyright © 2014-present Kriasoft, LLC. All rights reserved.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE.txt file in the root directory of this source tree.
 */

// Babel configuration
// https://babeljs.io/docs/usage/api/
module.exports = {
  plugins: [
    "@babel/plugin-syntax-dynamic-import",
    "@babel/plugin-transform-modules-commonjs",
    // Decorators
    ["@babel/plugin-proposal-decorators", { version: "legacy" }],
  ],
  presets: [
    ["@babel/preset-typescript", { allowDeclareFields: true }],
    [
      "@babel/preset-env",
      {
        targets: {
          node: "current",
        },
      },
    ],
    "@babel/preset-react",
  ],
  ignore: ["node_modules", "build"],
  env: {
    test: {
      plugins: ["istanbul"],
    },
  },
};
