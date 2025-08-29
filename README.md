# exiv2-wasm

> 🇰🇷 Read this in Korean: **[README.ko.md](README.ko.md)**

Use [Exiv2](https://exiv2.org/) in the browser via **WebAssembly**.  
A tiny C++ wrapper (embind) exposes simple functions to **read/write EXIF / IPTC / XMP**.  
Minimal deps are built for wasm (**expat, brotli dec/common, inih**); zlib comes from the Emscripten port.

---

## Online Demo
- [한국어 버전](https://daissue.app/exif-editor)
- [English version](https://daissue.app/en/exif-editor)

---

## Project structure

```
exiv2-wasm/
├─ exiv2/           # submodule (Exiv2)
├─ libexpat/        # submodule (expat)
├─ brotli/          # submodule (google/brotli)
├─ inih/            # submodule (benhoyt/inih)
├─ scripts/
│  ├─ build.ps1     # Windows PowerShell build
│  └─ build.bash    # Linux/macOS bash build
├─ wrapper.cpp      # embind wrapper (read/write metadata)
├─ index.html       # demo UI page
├─ dist/            # build outputs: exiv2.js / exiv2.wasm
└─ (build/, deps/)  # build cache / installed deps (git-ignored)
```

Clone with submodules:
```bash
git clone --recurse-submodules https://github.com/gerosyab/exiv2-wasm.git
```

---

## Prerequisites

### Tools
- **CMake**, **Ninja**
- **Emscripten SDK** (emcmake / emcc / em++ / emar)

**Windows (PowerShell)**
```powershell
winget install Kitware.CMake
winget install Ninja-build.Ninja
```

**Linux (Debian/Ubuntu)**
```bash
sudo apt update
sudo apt install -y cmake ninja-build python3
```

**Emscripten SDK (all OS)**
```bash
# anywhere you like
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest

# new shell(s):
source ./emsdk_env.sh      # Linux/macOS
# or on Windows PowerShell:
# .\emsdk_env.ps1
```
> Re-run `emsdk_env.sh` / `emsdk_env.ps1` in each new shell.

---

## Build

**Windows (PowerShell)**
```powershell
cd exiv2-wasm
# one-session policy (optional)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# clean build
.\scripts\build.ps1 -Clean
# incremental build
.\scripts\build.ps1
```

**Linux/macOS (bash/zsh)**
```bash
cd exiv2-wasm
chmod +x scripts/build.bash

# clean build
./scripts/build.bash -c
# incremental build
./scripts/build.bash
```

**Outputs:** `dist/exiv2.js` and `dist/exiv2.wasm`

---

## Run the demo

```bash
# from project root
python -m http.server 8080
# open:
# http://localhost:8080/index.html
```

---

## JavaScript usage

**Wrapper API:**

- `read(u8: Uint8Array) -> { exif: Object, iptc: Object, xmp: Object }`
- `readTagText(u8, key: string) -> string | null`
- `readTagBytes(u8, key: string) -> Uint8Array | null`
- `writeString(u8, key: string, value: string) -> Uint8Array`  (returns new buffer)
- `writeBytes(u8, key: string, data: Uint8Array) -> Uint8Array`

**Browser (CDN + `<script>` global function)**
```html
<script src="https://unpkg.com/exiv2-wasm"></script>
<script>
  (async () => {
    const exiv2 = await createExiv2Module();

    async function fileToU8(file) {
      const buf = await file.arrayBuffer();
      return new Uint8Array(buf);
    }

    document.querySelector('#file').addEventListener('change', async (e) => {
      const u8 = await fileToU8(e.target.files[0]);
      const meta = exiv2.read(u8);
      console.log('Camera Model:', meta.exif['Exif.Image.Model']);
    });
  })();
</script>
<input id="file" type="file" accept="image/*">
```

**Browser (CDN + ESM import)**
```js
<script type="module">
  import { createExiv2Module } from 'https://cdn.jsdelivr.net/npm/exiv2-wasm/+esm';

  const exiv2 = await createExiv2Module();

  const input = document.querySelector('#file');
  input.addEventListener('change', async (e) => {
    const file = e.target.files[0];
    const buf = new Uint8Array(await file.arrayBuffer());
    const meta = exiv2.read(buf);
    console.log('Camera Model:', meta.exif['Exif.Image.Model']);
  });
</script>
<input id="file" type="file" accept="image/*">
```

**ESM (Node.js / Vite / webpack / Rollup)**
```
import { createExiv2Module } from 'exiv2-wasm';

const exiv2 = await createExiv2Module();

const fs = await import('fs/promises');
const u8 = new Uint8Array(await fs.readFile('image.jpg'));
const meta = exiv2.read(u8);
console.log('Model:', meta.exif['Exif.Image.Model']);
```

**CommonJS**
```js
const { createExiv2Module } = require('exiv2-wasm');
const fs = require('fs');

function fileToU8(path) {
  return new Uint8Array(fs.readFileSync(path));
}

createExiv2Module().then((exiv2) => {
  const u8 = fileToU8('image.jpg');
  const meta = exiv2.read(u8);
  console.log('Model:', meta.exif['Exif.Image.Model']);
});
```

**Common keys (examples)**
- Camera: `Exif.Image.Make`, `Exif.Image.Model`
- Exposure: `Exif.Photo.ExposureTime`, `Exif.Photo.ShutterSpeedValue`
- Aperture: `Exif.Photo.FNumber`, `Exif.Photo.ApertureValue`
- ISO: `Exif.Photo.PhotographicSensitivity` (or `Exif.Photo.ISOSpeedRatings`)
- Title/Author/Comment:  
  - XMP: `Xmp.dc.title`, `Xmp.dc.creator`, `Xmp.dc.description`  
  - EXIF: `Exif.Image.ImageDescription`, `Exif.Image.Artist`, `Exif.Photo.UserComment`  
  - **Windows XP* Unicode**: `Exif.Image.XPTitle`, `Exif.Image.XPAuthor`, `Exif.Image.XPComment` (UTF-16LE)

---

## Notes
- Exiv2 CLI build is disabled: `-DEXIV2_BUILD_EXIV2_COMMAND=OFF`
- BMFF/HEIF support enabled: `-DEXIV2_ENABLE_BMFF=ON`
- If submodules show empty after clone:  
  `git submodule update --init --recursive`
