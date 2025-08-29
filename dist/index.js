// dist/index.js — Universal ESM entry (browser & Node)

function urlDir(metaUrl) {
    const u = new URL(metaUrl);
    u.pathname = u.pathname.replace(/[^/]+$/, '');
    u.search = ''; u.hash = '';
    return u.toString();
  }
  
  async function importFactoryESM(exiv2JsUrl) {
    try {
      const mod = await import(/* @vite-ignore */ exiv2JsUrl);
      const cand = [mod?.default, mod?.Module, mod];
      const fn = cand.find((c) => typeof c === 'function');
      return fn || null;
    } catch {
      return null;
    }
  }
  
  function injectClassicScript(srcUrl) {
    return new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = srcUrl;
      s.async = true;
      s.onload = () => resolve();
      s.onerror = () => reject(new Error('[exiv2-wasm] Script load failed: ' + srcUrl));
      document.head.appendChild(s);
    });
  }
  
  function findGlobalFactory() {
    const names = ['Exiv2Factory', 'Exiv2Module', 'Module'];
    for (const n of names) {
      const v = globalThis && globalThis[n];
      if (typeof v === 'function') return v;
    }
    return null;
  }
  
  export async function createExiv2Module(options = {}) {
    const isBrowser = typeof window !== 'undefined' && typeof document !== 'undefined';
    const here = urlDir(import.meta.url); // .../dist/
    const exiv2Js = new URL('./exiv2.js', here).toString();
    const wasmUrlDefault = new URL('./exiv2.wasm', here).toString();
  
    const userLocate = options?.locateFile;
    const locateFile = (p) =>
      typeof userLocate === 'function'
        ? userLocate(p)
        : (p.endsWith('.wasm') ? wasmUrlDefault : p);
  
    if (!isBrowser) {
      // Node ESM
      const fn = await importFactoryESM(exiv2Js);
      if (!fn) throw new Error('[exiv2-wasm] Could not import exiv2.js in Node ESM.');
      return fn({ ...options, locateFile });
    }
  
    // Browser: try ESM then classic-script fallback
    let factory = await importFactoryESM(exiv2Js);
    if (!factory) {
      await injectClassicScript(exiv2Js);
      factory = findGlobalFactory();
    }
    if (!factory) throw new Error('[exiv2-wasm] Failed to resolve Emscripten factory from exiv2.js.');
    return factory({ ...options, locateFile });
  }
  
  export default createExiv2Module;
  