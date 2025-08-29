'use strict';
const path = require('path');

function pick(mod) {
  if (typeof mod === 'function') return mod;
  if (mod && typeof mod.createExiv2Module === 'function') return mod.createExiv2Module;
  if (mod && typeof mod.default === 'function') return mod.default;
  return null;
}

async function createExiv2Module(options = {}) {
  // 1) CJS require로 UMD 시도
  let mod;
  try { mod = require('./exiv2.js'); } catch (_) {}
  let factory = pick(mod);

  // 2) ESM 빌드가 있다면 동적 import (Node ESM 호환 위해)
  if (!factory) {
    try {
      const m = await import('./exiv2.esm.js');
      factory = pick(m);
    } catch (_) {}
  }

  if (!factory) {
    throw new Error('[exiv2-wasm] cannot resolve exiv2 factory (CJS).');
  }

  const userLocate = options && options.locateFile;
  const locateFile = (p) => (typeof userLocate === 'function'
    ? userLocate(p)
  : (p.endsWith('.wasm') ? path.join(__dirname, p) : p));
  return factory({ ...options, locateFile });
}

module.exports = createExiv2Module;
module.exports.createExiv2Module = createExiv2Module;
