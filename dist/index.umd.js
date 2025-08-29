;(function (root, factory) {
    if (typeof define === 'function' && define.amd) define([], function () { return factory(root); });
    else if (typeof exports === 'object' && typeof module !== 'undefined') module.exports = factory(root);
    else root.createExiv2Module = factory(root);
  }(typeof self !== 'undefined' ? self : this, function (root) {
    'use strict';
  
    function curScriptDir() {
      var s = document.currentScript || (function(arr){return arr[arr.length-1];})(document.getElementsByTagName('script'));
      var a = document.createElement('a'); a.href = s.src;
      return a.href.replace(/[^/]+$/, '');
    }
    function load(src) { return new Promise(function(res, rej){ var el=document.createElement('script'); el.src=src; el.async=true; el.onload=res; el.onerror=function(){rej(new Error(src));}; document.head.appendChild(el); }); }
    function makeLocate(base){ 
        return function(p){ 
          return /\.wasm$/i.test(p) ? base + p : p; 
        }; 
      }
  
    function createExiv2Module(opts) {
      opts = opts || {};
      return new Promise(function(resolve, reject) {
        var base = (document.currentScript && document.currentScript.getAttribute('data-exiv2-base')) || curScriptDir();
        var tried = [];
        function attempt(b){
          var url = b + 'exiv2.js'; tried.push(url);
          load(url).then(function(){
            var f = root.createExiv2Module || root.Exiv2Module || root.Module;
            if (typeof f !== 'function') return reject(new Error('[exiv2-wasm] Loaded but no global createExiv2Module/Exiv2Module/Module'));
            var userLocate = opts.locateFile; var locate = (typeof userLocate==='function')?userLocate:makeLocate(b);
            Promise.resolve(f(Object.assign({}, opts, { locateFile: locate }))).then(resolve, reject);
          }).catch(function(){
            // fallback to common CDNs
            if (b.indexOf('unpkg.com') === -1) attempt('https://unpkg.com/exiv2-wasm/dist/');
            else if (b.indexOf('jsdelivr.net') === -1) attempt('https://cdn.jsdelivr.net/npm/exiv2-wasm/dist/');
            else reject(new Error('[exiv2-wasm] Failed to load exiv2.js from: '+ tried.join(', ')));
          });
        }
        attempt(base.replace(/\/?$/, '/'));
      });
    }
  
    return createExiv2Module;
  }));
  