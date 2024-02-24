const log = require("../utils/logger")("action:test");

// Entrypoint for the Defender Action
const handler = async () => {
  console.log(`DEBUG env var in handler before being set: "${process.env.DEBUG}"`);

  log(`Test log message`);

  console.log(`log using console.log`);
};

module.exports = { handler };
