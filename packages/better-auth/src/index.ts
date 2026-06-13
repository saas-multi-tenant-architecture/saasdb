export { smtaPlugin } from './plugin/index';
export type { SMTAPluginOptions } from './plugin/index';
export type { SMTASessionFields } from './plugin/session';
export { withSMTA, injectUserContext, clearUserContext } from './middleware/inject-user-context';
