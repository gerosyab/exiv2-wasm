// dist/index.cjs — CommonJS entry (Node)
'use strict';
const path = require('path');

function pickFactory(mod) {
  const cand = [mod, mod && mod.default, mod && mod.Module, mod && mod.default && mod.default.Module];
  return cand.find((c) => typeof c === 'function') || null;
}

async function createExiv2Module(options = {}) {
  let mod;
  try { mod = require('./exiv2.js'); } catch (_) {}
  if (!mod) { try { mod = require('./exiv2.cjs'); } catch (_) {} }

  const factory = pickFactory(mod);
  if (!factory) throw new Error('[exiv2-wasm] Failed to resolve Emscripten factory from exiv2.(js|cjs) in CJS.');

  const userLocate = options && options.locateFile;
  const locateFile = (p) => (typeof userLocate === 'function'
    ? userLocate(p)
    : (p.endsWith('.wasm') ? path.join(__dirname, 'exiv2.wasm') : p));

  return factory({ ...options, locateFile });
}

module.exports = createExiv2Module;
module.exports.createExiv2Module = createExiv2Module;
