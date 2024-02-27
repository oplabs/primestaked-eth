const debug = require("debug");

// https://www.npmjs.com/package/debug#output-streams
// set all output to go via console.log instead of stderr
// This is needed for Defender Actions to capture the logs
debug.log = console.log.bind(console);

/**
 * Creates a logger for a module.
 * @example
 *   const log = require("../utils/logger")("task:deposits");
 *   log('something interesting happened');
 * @param {string} module name of the module to log for. eg "task:deposits"
 */
const logger = (module) => debug(`prime:${module}`);

module.exports = logger;
