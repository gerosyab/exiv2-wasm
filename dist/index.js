// dist/index.js (ESM)
export async function createExiv2Module(options = {}) {
    // emscripten glue (MODULARIZE=1)
    const modFactory = (await import('./exiv2.js')).default ?? (await import('./exiv2.js'));
    return modFactory({
      ...options,
      locateFile: (path) =>
        path.endsWith('.wasm')
          ? new URL('./exiv2.wasm', import.meta.url).toString()
          : path,
    });
  }
  