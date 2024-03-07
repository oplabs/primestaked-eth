const resolve = require("@rollup/plugin-node-resolve");
const commonjs = require("@rollup/plugin-commonjs");
const json = require("@rollup/plugin-json");
const builtins = require("builtin-modules");

const commonConfig = {
  plugins: [resolve({ preferBuiltins: true, exportConditions: ["node"] }), commonjs(), json({ compact: true })],
  // Do not bundle these packages.
  // ethers is required to be bundled even though its an Autotask package.
  external: [
    ...builtins,
    "axios",
    "chai",
    /^defender-relay-client(\/.*)?$/,
    "@nomicfoundation/solidity-analyzer-darwin-x64",
    "fsevents",
  ],
};

module.exports = [
  {
    ...commonConfig,
    input: "depositAllEL.js",
    output: {
      file: "dist/depositAllEL/index.js",
      format: "cjs",
    },
  },
  {
    ...commonConfig,
    input: "operateValidators.js",
    output: {
      file: "dist/operateValidators/index.js",
      format: "cjs",
    },
  },
  {
    ...commonConfig,
    input: "transferWETH.js",
    output: {
      file: "dist/transferWETH/index.js",
      format: "cjs",
    },
  },
];
