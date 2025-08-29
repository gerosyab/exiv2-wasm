// dist/index.umd.js — auto-resolving UMD for <script> usage
;(function (root, factory) {
    if (typeof define === 'function' && define.amd) {
      define([], function () { return factory(root, true); });
    } else if (typeof exports === 'object' && typeof module !== 'undefined') {
      module.exports = factory(root, false);
    } else {
      root.createExiv2Module = factory(root, true);
    }
  }(typeof self !== 'undefined' ? self : this, function (root, isBrowser) {
    'use strict';
  
    // ---- helpers ------------------------------------------------------------
    function getCurrentScript() {
      var s = document.currentScript;
      if (!s) {
        var scripts = document.getElementsByTagName('script');
        s = scripts[scripts.length - 1];
      }
      return s;
    }
  
    function dirOf(url) {
      return url.replace(/[#?].*$/, '').replace(/[^/]+$/, '');
    }
  
    function tryLoadScript(src) {
      return new Promise(function (resolve, reject) {
        var el = document.createElement('script');
        el.src = src;
        el.async = true;
        el.onload = function () { resolve(src); };
        el.onerror = function () { reject(new Error(src)); };
        document.head.appendChild(el);
      });
    }
  
    function chainLoad(urls) {
      // try candidates sequentially until one loads
      var i = 0;
      function next() {
        if (i >= urls.length) return Promise.reject(new Error('all failed'));
        var u = urls[i++]; return tryLoadScript(u).catch(next);
      }
      return next();
    }
  
    // Build candidate base URLs for exiv2.js / exiv2.wasm
    function buildBaseCandidates() {
      var s = getCurrentScript();
      var attrBase = s && s.getAttribute('data-exiv2-base');
      var globalBase = root.EXIV2_WASM_BASE;
  
      // 1) explicit override wins
      if (attrBase) return [attrBase];
      if (globalBase) return [globalBase];
  
      // 2) derive from current script src
      var here = dirOf(s && s.src ? s.src : '');
      var pkgRoot = here.replace(/\/dist\/?$/, '/'); // if already in /dist/, this gives package root
  
      // common CDN fallbacks
      var cdn1 = 'https://unpkg.com/exiv2-wasm/dist/';
      var cdn2 = 'https://cdn.jsdelivr.net/npm/exiv2-wasm/dist/';
  
      // Try in this order:
      // - same dir (if index.umd.js sits with exiv2.js)
      // - same dir + dist/ (in case umd is at package root)
      // - package root + dist/
      // - CDN fallbacks
      var arr = [];
      if (here) arr.push(here);                // ./ (same folder)
      if (here && !/\/dist\/$/.test(here)) {
        arr.push(here + 'dist/');              // ./dist/
      }
      if (pkgRoot && !/\/dist\/$/.test(pkgRoot)) {
        arr.push(pkgRoot + 'dist/');           // pkgRoot/dist/
      }
      arr.push(cdn1, cdn2);
      // dedupe while preserving order
      var seen = Object.create(null);
      var out = [];
      for (var i=0;i<arr.length;i++) {
        var u = arr[i];
        if (!u || seen[u]) continue;
        seen[u] = true; out.push(u);
      }
      return out;
    }
  
    function makeLocateFile(base) {
      return function locateFile(p) {
        // If user provided a custom hook, UMD will overwrite it below
        return /\.wasm$/i.test(p) ? (base + 'exiv2.wasm') : p;
      };
    }
  
    // ---- main ---------------------------------------------------------------
    function createExiv2Module(userOpts) {
      if (!isBrowser) {
        // UMD is for browsers; Node should import CJS/ESM entries instead.
        return Promise.reject(new Error('[exiv2-wasm] UMD build is browser-only.'));
      }
      userOpts = userOpts || {};
  
      var bases = buildBaseCandidates();
      var exiv2Candidates = bases.map(function (b) { return b + 'exiv2.js'; });
      var chosenBase = null;
  
      // 1) Load exiv2.js by trying candidates
      return chainLoad(exiv2Candidates)
        .then(function (loadedUrl) {
          chosenBase = dirOf(loadedUrl) + ''; // ensure trailing slash
          // 2) find the global factory exposed by exiv2.js
          var names = ['Exiv2Factory', 'Exiv2Module', 'Module'];
          var factory = null;
          for (var i=0;i<names.length;i++) {
            var v = root[names[i]];
            if (typeof v === 'function') { factory = v; break; }
          }
          if (!factory) {
            throw new Error('[exiv2-wasm] Loaded exiv2.js but could not find a global factory (Module/Exiv2Module/Exiv2Factory).');
          }
  
          // 3) create module with proper locateFile (prefer user, otherwise our base)
          var userLocate = userOpts.locateFile;
          var locate = (typeof userLocate === 'function') ? userLocate : makeLocateFile(chosenBase);
  
          var opts = {};
          for (var k in userOpts) opts[k] = userOpts[k];
          opts.locateFile = locate;
  
          var mod = factory(opts);
          return Promise.resolve(mod);
        });
    }
  
    return createExiv2Module;
  }));
  