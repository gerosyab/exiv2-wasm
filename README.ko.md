# exiv2-wasm

브라우저에서 **WebAssembly**로 [Exiv2](https://exiv2.org/)를 사용합니다.  
작은 C++ 래퍼(embind)가 **EXIF / IPTC / XMP 메타데이터 읽기·쓰기** API를 제공합니다.  
필수 의존성(**expat, brotli dec/common, inih**)은 wasm으로 빌드하고, zlib은 Emscripten 포트를 사용합니다.

---

## Online Demo
- [한국어 버전](https://daissue.app/exif-editor)
- [English version](https://daissue.app/en/exif-editor)

---

## 프로젝트 구조

```
exiv2-wasm/
├─ exiv2/           # 서브모듈 (Exiv2)
├─ libexpat/        # 서브모듈 (expat)
├─ brotli/          # 서브모듈 (google/brotli)
├─ inih/            # 서브모듈 (benhoyt/inih)
├─ scripts/
│  ├─ build.ps1     # Windows PowerShell 빌드
│  └─ build.bash    # Linux/macOS bash 빌드
├─ wrapper.cpp      # embind 래퍼 (read/write)
├─ index.html       # 데모 UI
├─ dist/            # 빌드 결과: exiv2.js / exiv2.wasm
└─ (build/, deps/)  # 빌드 캐시/설치물 (git-ignored)
```

서브모듈 포함 클론:
```bash
git clone --recurse-submodules https://github.com/gerosyab/exiv2-wasm.git
```

---

## 사전 준비

### 도구
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

**Emscripten SDK (공통)**
```bash
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest

# 새 셸마다 환경 적용
source ./emsdk_env.sh      # Linux/macOS
# Windows PowerShell: .\emsdk_env.ps1
```
> 새 터미널을 열 때마다 `emsdk_env.sh` / `emsdk_env.ps1`를 실행하세요.

---

## 빌드

**Windows (PowerShell)**
```powershell
cd exiv2-wasm
# (선택) 이 세션만 스크립트 허용
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# 클린 빌드
.\scripts\build.ps1 -Clean
# 증분 빌드
.\scripts\build.ps1
```

**Linux/macOS (bash/zsh)**
```bash
cd exiv2-wasm
chmod +x scripts/build.bash

# 클린 빌드
./scripts/build.bash -c
# 증분 빌드
./scripts/build.bash
```

**빌드 결과:** `dist/exiv2.js`, `dist/exiv2.wasm`

---

## 데모 실행

```bash
# 프로젝트 루트에서
python -m http.server 8080
# 접속:
# http://localhost:8080/index.html
```

---

## JavaScript 사용 예

노출 API:

- `read(u8: Uint8Array) -> { exif: Object, iptc: Object, xmp: Object }`
- `readTagText(u8, key: string) -> string | null`
- `readTagBytes(u8, key: string) -> Uint8Array | null`
- `writeString(u8, key: string, value: string) -> Uint8Array`
- `writeBytes(u8, key: string, data: Uint8Array) -> Uint8Array`

```html
<script src="dist/exiv2.js"></script>
<script>
let exiv2;
createExiv2Module().then(m => exiv2 = m);

async function fileToU8(file) {
  const buf = await file.arrayBuffer();
  return new Uint8Array(buf);
}

// 전체 메타 읽기
async function showMeta(file) {
  const u8 = await fileToU8(file);
  const meta = exiv2.read(u8);     // { exif:{}, iptc:{}, xmp:{} }
  console.log(meta.exif["Exif.Image.Model"]); // 카메라 모델
}

// 제목 쓰기(XMP) 후 다운로드
async function writeTitle(file, title) {
  let u8 = await fileToU8(file);
  u8 = exiv2.writeString(u8, "Xmp.dc.title", title);

  // 선택: Windows XP* 유니코드 필드(UTF-16LE) 동기화
  // const xp = utf8ToXpBytes(title); u8 = exiv2.writeBytes(u8, "Exif.Image.XPTitle", xp);

  const blob = new Blob([u8], {type: file.type || "image/jpeg"});
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = file.name.replace(/(\.\w+)?$/, "_with_meta$1");
  a.click();
  URL.revokeObjectURL(a.href);
}
</script>
```

**자주 쓰는 키 예시**
- 카메라: `Exif.Image.Make`, `Exif.Image.Model`
- 노출: `Exif.Photo.ExposureTime`, `Exif.Photo.ShutterSpeedValue`
- 조리개: `Exif.Photo.FNumber`, `Exif.Photo.ApertureValue`
- ISO: `Exif.Photo.PhotographicSensitivity` (또는 `Exif.Photo.ISOSpeedRatings`)
- 제목/저자/설명:  
  - XMP: `Xmp.dc.title`, `Xmp.dc.creator`, `Xmp.dc.description`  
  - EXIF: `Exif.Image.ImageDescription`, `Exif.Image.Artist`, `Exif.Photo.UserComment`  
  - **Windows XP* 유니코드 필드**: `Exif.Image.XPTitle`, `Exif.Image.XPAuthor`, `Exif.Image.XPComment` (UTF-16LE)

---

## 참고
- Exiv2 CLI 빌드는 비활성화됨: `-DEXIV2_BUILD_EXIV2_COMMAND=OFF`
- BMFF/HEIF 지원 활성화: `-DEXIV2_ENABLE_BMFF=ON`
- 서브모듈이 비어 보이면:  
  `git submodule update --init --recursive`
