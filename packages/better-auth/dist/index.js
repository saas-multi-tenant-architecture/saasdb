"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.clearUserContext = exports.injectUserContext = exports.withSMTA = exports.smtaPlugin = void 0;
var index_1 = require("./plugin/index");
Object.defineProperty(exports, "smtaPlugin", { enumerable: true, get: function () { return index_1.smtaPlugin; } });
var inject_user_context_1 = require("./middleware/inject-user-context");
Object.defineProperty(exports, "withSMTA", { enumerable: true, get: function () { return inject_user_context_1.withSMTA; } });
Object.defineProperty(exports, "injectUserContext", { enumerable: true, get: function () { return inject_user_context_1.injectUserContext; } });
Object.defineProperty(exports, "clearUserContext", { enumerable: true, get: function () { return inject_user_context_1.clearUserContext; } });
