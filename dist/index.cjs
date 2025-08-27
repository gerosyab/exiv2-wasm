// dist/index.cjs (CommonJS)
const path = require('path');
const glue = require('./exiv2.js'); // emscripten glue (MODULARIZE=1)

function createExiv2Module(options = {}) {
  const modFactory = glue.default || glue; // default or function
  return modFactory({
    ...options,
    locateFile: (p) => (p.endsWith('.wasm') ? path.join(__dirname, 'exiv2.wasm') : p),
  });
}

module.exports = { createExiv2Module };
