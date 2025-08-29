function urlDir(metaUrl) {
    const u = new URL(metaUrl);
    u.pathname = u.pathname.replace(/[^/]+$/, '');
    u.search = ''; u.hash = '';
    return u.toString();
  }
  
  async function importFactory(here) {
    // 🔧 반드시 dist/를 붙여서 시도 (CDN +esm에서도 안전)
    const esmUrl = new URL('./dist/exiv2.esm.js', here).toString();
    const umdUrl = new URL('./dist/exiv2.js', here).toString();
  
    // 1) 진짜 ESM 우선
    try {
      const m = await import(/* @vite-ignore */ esmUrl);
      const fn = m?.default || m?.createExiv2Module;
      if (typeof fn === 'function') return fn;
    } catch (_) {}
  
    // 2) 브라우저면 UMD로 폴백 (전역 함수 사용)
    if (typeof window !== 'undefined' && typeof document !== 'undefined') {
      await new Promise((res, rej) => {
        const s = document.createElement('script');
        s.src = umdUrl; s.async = true;
        s.onload = res; s.onerror = () => rej(new Error('[exiv2-wasm] failed to load ' + umdUrl));
        document.head.appendChild(s);
      });
      if (typeof globalThis.createExiv2Module === 'function') return globalThis.createExiv2Module;
    }
  
    throw new Error('[exiv2-wasm] cannot resolve exiv2 factory (ESM).');
  }
  
  export async function createExiv2Module(options = {}) {
    const here = urlDir(import.meta.url); // 패키지 루트처럼 보여도 ok
    const userLocate = options?.locateFile;
  
    // 🔧 wasm도 dist/에서 파일명 그대로 찾기
    const locateFile = (p) =>
      typeof userLocate === 'function'
        ? userLocate(p)
        : (p.endsWith('.wasm') ? new URL(`./dist/${p}`, here).toString() : p);
  
    const factory = await importFactory(here);
    return factory({ ...options, locateFile });
  }
  
  export default createExiv2Module;
  