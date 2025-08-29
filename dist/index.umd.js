// dist/index.umd.js — UMD build for <script> CDN usage
;(function (root, factory) {
    if (typeof define === 'function' && define.amd) {
      define([], function () { return factory(root); });
    } else if (typeof exports === 'object' && typeof module !== 'undefined') {
      module.exports = factory(root);
    } else {
      root.createExiv2Module = factory(root);
    }
  }(typeof self !== 'undefined' ? self : this, function (root) {
    'use strict';
  
    function urlDirFromCurrentScript() {
      var s = document.currentScript;
      if (!s) {
        var scripts = document.getElementsByTagName('script');
        s = scripts[scripts.length - 1];
      }
      var a = document.createElement('a');
      a.href = s.src;
      return a.href.replace(/[^/]+$/, '');
    }
  
    function injectClassicScript(src, cb, eb) {
      var el = document.createElement('script');
      el.src = src;
      el.async = true;
      el.onload = cb;
      el.onerror = function () { eb(new Error('[exiv2-wasm] Script load failed: ' + src)); };
      document.head.appendChild(el);
    }
  
    function findGlobalFactory() {
      var names = ['Exiv2Factory', 'Exiv2Module', 'Module'];
      for (var i=0;i<names.length;i++) {
        var v = root[names[i]];
        if (typeof v === 'function') return v;
      }
      return null;
    }
  
    function createExiv2Module(options) {
      options = options || {};
      return new Promise(function (resolve, reject) {
        var here = urlDirFromCurrentScript(); // .../dist/
        var exiv2Js = here + 'exiv2.js';
        var wasmUrlDefault = here + 'exiv2.wasm';
  
        var userLocate = options.locateFile;
        var locateFile = function (p) {
          if (typeof userLocate === 'function') return userLocate(p);
          return p.endsWith('.wasm') ? wasmUrlDefault : p;
        };
  
        function ensureAndResolve() {
          var factory = findGlobalFactory();
          if (!factory) return reject(new Error('[exiv2-wasm] Global factory not found after loading exiv2.js'));
          try {
            var mod = factory(Object.assign({}, options, { locateFile: locateFile }));
            Promise.resolve(mod).then(resolve, reject);
          } catch (e) { reject(e); }
        }
  
        var factory = findGlobalFactory();
        if (factory) ensureAndResolve();
        else injectClassicScript(exiv2Js, ensureAndResolve, reject);
      });
    }
  
    return createExiv2Module;
  }));
  