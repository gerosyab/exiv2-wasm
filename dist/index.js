// import ESM 전용 빌드가 있으면 그걸 우선
async function importFactory(here) {
    const esmUrl = new URL('./exiv2.esm.js', here).toString();
    const umdUrl = new URL('./exiv2.js', here).toString();
  
    // 1) 순정 ESM 시도
    try {
      const m = await import(/* @vite-ignore */ esmUrl);
      const fn = m?.default || m?.createExiv2Module;
      if (typeof fn === 'function') return fn;
    } catch (_) {}
  
    // 2) UMD를 dynamic import 하면 네임스페이스가 오기도 해서 보장 어려움 → 전역 폴백
    if (typeof window !== 'undefined' && typeof document !== 'undefined') {
      await new Promise((res, rej) => {
        const s = document.createElement('script');
        s.src = umdUrl;
        s.async = true;
        s.onload = res;
        s.onerror = () => rej(new Error('[exiv2-wasm] failed to load ' + umdUrl));
        document.head.appendChild(s);
      });
      if (typeof globalThis.createExiv2Module === 'function') return globalThis.createExiv2Module;
    }
  
    // 3) Node ESM에서 UMD require될 때는 CJS 엔트리 사용 권장
    throw new Error('[exiv2-wasm] cannot resolve exiv2 factory (ESM).');
  }
  
  function urlDir(metaUrl) {
    const u = new URL(metaUrl);
    u.pathname = u.pathname.replace(/[^/]+$/, '');
    u.search = ''; u.hash = '';
    return u.toString();
  }
  
  export async function createExiv2Module(options = {}) {
    const here = urlDir(import.meta.url);
  
    const userLocate = options?.locateFile;
    const locateFile = (p) => (typeof userLocate === 'function'
        ? userLocate(p)
        : (p.endsWith('.wasm') ? new URL(p, here).toString() : p));
  
    const factory = await importFactory(here);
    return factory({ ...options, locateFile });
  }
  
  export default createExiv2Module;
  