const debug = require("debug");

/**
 * Creates a logger for a module.
 * @example
 *   const log = require("../utils/logger")("task:deposits");
 *   log('something interesting happened');
 * @param {string} module name of the module to log for. eg "task:deposits"
 */
const logger = (module) => debug(`prime:${module}`);

module.exports = logger;
