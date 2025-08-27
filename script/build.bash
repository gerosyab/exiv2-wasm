#!/usr/bin/env bash
set -euo pipefail

# ============================================
# exiv2-wasm build (Linux, bash)
# deps: emsdk (emcmake/emcc/em++/emar), cmake, ninja
# usage: ./scripts/build.bash [-c|--clean]
# outputs: dist/exiv2.js, dist/exiv2.wasm
# ============================================

CLEAN=0
if [[ "${1:-}" == "-c" || "${1:-}" == "--clean" ]]; then
  CLEAN=1
fi

# --- paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BUILD_DIR="${PROJECT_ROOT}/build"
DIST_DIR="${PROJECT_ROOT}/dist"
mkdir -p "${DIST_DIR}"

DEPS_PREFIX="${PROJECT_ROOT}/deps/install"
DEPS_INC="${DEPS_PREFIX}/include"
DEPS_LIB="${DEPS_PREFIX}/lib"

EXPAT_SRC="${PROJECT_ROOT}/libexpat/expat"
EXPAT_BUILD="${BUILD_DIR}/build-expat"

BROTLI_SRC="${PROJECT_ROOT}/brotli"
BROTLI_BUILD="${BUILD_DIR}/build-brotli"

INIH_SRC="${PROJECT_ROOT}/inih"
INIH_TMP="${PROJECT_ROOT}/deps/tmp-inih"

# --- helpers ---
need() { command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' not found. $2" >&2; exit 1; }; }
msg()  { echo -e "\033[1;36m$*\033[0m"; }
ok()   { echo -e "\033[1;32m$*\033[0m"; }
warn() { echo -e "\033[1;33m$*\033[0m"; }

# --- emsdk env (auto if possible) ---
if ! command -v emcc >/dev/null 2>&1; then
  if [[ -n "${EMSDK:-}" && -f "${EMSDK}/emsdk_env.sh" ]]; then
    msg "[env] sourcing EMSDK from \$EMSDK"
    # shellcheck disable=SC1090
    source "${EMSDK}/emsdk_env.sh" >/dev/null
  elif [[ -f "${PROJECT_ROOT}/../emsdk/emsdk_env.sh" ]]; then
    msg "[env] sourcing EMSDK from ../emsdk"
    # shellcheck disable=SC1090
    source "${PROJECT_ROOT}/../emsdk/emsdk_env.sh" >/dev/null
  else
    echo "error: emcc not found and EMSDK not located. Run emsdk_env.sh first." >&2
    exit 1
  }
fi

# --- tools ---
need emcmake "Activate emsdk (source emsdk_env.sh)."
need emcc    "Install Emscripten SDK."
need em++    "Install Emscripten SDK."
need emar    "Install Emscripten SDK."
need cmake   "Install CMake."
need ninja   "Install Ninja (e.g. apt install ninja-build)."

msg "[check] Using Emscripten: $(emcc --version | head -n 1)"

# --- clean ---
if [[ $CLEAN -eq 1 ]]; then
  msg "[clean] removing outputs..."
  rm -rf "${BUILD_DIR}" "${DIST_DIR}" "${DEPS_PREFIX}" "${EXPAT_BUILD}" "${BROTLI_BUILD}" "${INIH_TMP}"
fi

# --- ensure dirs ---
mkdir -p "${BUILD_DIR}" "${DEPS_INC}" "${DEPS_LIB}"

# ========== 1) EXPAT (static) ==========
EXPAT_A="${DEPS_LIB}/libexpat.a"
if [[ ! -f "${EXPAT_A}" ]]; then
  [[ -d "${EXPAT_SRC}" ]] || { echo "error: expat source missing at ${EXPAT_SRC}"; exit 1; }
  msg "[expat] configure"
  emcmake cmake -S "${EXPAT_SRC}" -B "${EXPAT_BUILD}" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${DEPS_PREFIX}" \
    -DBUILD_SHARED_LIBS=OFF \
    -DEXPAT_BUILD_TOOLS=OFF \
    -DEXPAT_BUILD_TESTS=OFF \
    -DEXPAT_BUILD_EXAMPLES=OFF
  msg "[expat] build & install"
  cmake --build "${EXPAT_BUILD}" --target install --parallel
else
  ok "[expat] using cached ${EXPAT_A}"
fi

# ========== 2) Brotli (static: common/dec) ==========
BROTLI_COMMON_A="${DEPS_LIB}/libbrotlicommon.a"
BROTLI_DEC_A="${DEPS_LIB}/libbrotlidec.a"
if [[ ! -f "${BROTLI_COMMON_A}" || ! -f "${BROTLI_DEC_A}" ]]; then
  [[ -d "${BROTLI_SRC}" ]] || { echo "error: brotli source missing at ${BROTLI_SRC}"; exit 1; }
  msg "[brotli] configure"
  emcmake cmake -S "${BROTLI_SRC}" -B "${BROTLI_BUILD}" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DBROTLI_BUILD_TOOLS=OFF \
    -DBROTLI_DISABLE_TESTS=ON \
    -DCMAKE_INSTALL_PREFIX="${DEPS_PREFIX}"
  msg "[brotli] build libs"
  cmake --build "${BROTLI_BUILD}" --target brotlicommon --parallel
  cmake --build "${BROTLI_BUILD}" --target brotlidec    --parallel
  # locate built libs and copy
  bcommon="$(find "${BROTLI_BUILD}" -name 'libbrotlicommon.a' | head -n 1 || true)"
  bdec="$(find "${BROTLI_BUILD}" -name 'libbrotlidec.a' | head -n 1 || true)"
  [[ -n "${bcommon}" && -n "${bdec}" ]] || { echo "error: brotli libs not found after build"; exit 1; }
  cp -f "${bcommon}" "${BROTLI_COMMON_A}"
  cp -f "${bdec}"    "${BROTLI_DEC_A}"
  # headers
  mkdir -p "${DEPS_INC}/brotli"
  cp -rf "${BROTLI_SRC}/c/include/brotli/"* "${DEPS_INC}/brotli/"
else
  ok "[brotli] using cached libs in ${DEPS_LIB}"
fi

# ========== 3) INIH (manual static) ==========
INIH_A="${DEPS_LIB}/libinih.a"
INIREADER_A="${DEPS_LIB}/libinireader.a"
if [[ ! -f "${INIH_A}" || ! -f "${INIREADER_A}" ]]; then
  [[ -d "${INIH_SRC}" ]] || { echo "error: inih source missing at ${INIH_SRC}"; exit 1; }
  msg "[inih] compile static libs"
  mkdir -p "${INIH_TMP}"
  cp -f "${INIH_SRC}/ini.h" "${DEPS_INC}/ini.h"
  cp -f "${INIH_SRC}/cpp/INIReader.h" "${DEPS_INC}/INIReader.h"
  pushd "${INIH_TMP}" >/dev/null
  emcc -O2 -I "${DEPS_INC}" -I "${INIH_SRC}" -c "${INIH_SRC}/ini.c" -o ini.o
  em++ -O2 -I "${DEPS_INC}" -I "${INIH_SRC}" -c "${INIH_SRC}/cpp/INIReader.cpp" -o INIReader.o
  emar rcs "${INIH_A}" ini.o
  emar rcs "${INIREADER_A}" INIReader.o
  popd >/dev/null
  rm -rf "${INIH_TMP}"
else
  ok "[inih] using cached ${INIH_A}, ${INIREADER_A}"
fi

# ========== 4) Exiv2 configure & build ==========
msg "[exiv2] configure (emcmake cmake)"
emcmake cmake -S "${PROJECT_ROOT}/exiv2" -B "${BUILD_DIR}" -G Ninja \
  -DBUILD_SHARED_LIBS=OFF \
  -DEXIV2_ENABLE_NLS=OFF \
  -DEXIV2_ENABLE_VIDEO=OFF \
  -DEXIV2_ENABLE_WEBREADY=OFF \
  -DEXIV2_ENABLE_CURL=OFF \
  -DEXIV2_BUILD_SAMPLES=OFF \
  -DEXIV2_BUILD_UNIT_TESTS=OFF \
  -DEXIV2_BUILD_EXIV2_COMMAND=OFF \
  -DEXIV2_ENABLE_BMFF=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DEXPAT_INCLUDE_DIR="${DEPS_INC}" \
  -DEXPAT_LIBRARY="${EXPAT_A}" \
  -DBROTLI_INCLUDE_DIR="${DEPS_INC}" \
  -DBROTLIDEC_LIBRARY="${BROTLI_DEC_A}" \
  -DBROTLICOMMON_LIBRARY="${BROTLI_COMMON_A}" \
  -Dinih_INCLUDE_DIR="${DEPS_INC}" \
  -Dinih_LIBRARY="${INIH_A}" \
  -Dinih_inireader_INCLUDE_DIR="${DEPS_INC}" \
  -Dinih_inireader_LIBRARY="${INIREADER_A}"

msg "[exiv2] build"
cmake --build "${BUILD_DIR}" --parallel

# ========== 5) Link wrapper -> dist/exiv2.js/.wasm ==========
WRAPPER="${PROJECT_ROOT}/wrapper.cpp"
[[ -f "${WRAPPER}" ]] || { echo "error: wrapper.cpp missing at ${WRAPPER}"; exit 1; }

msg "[link] em++ wrapper -> dist"
em++ -O3 "${WRAPPER}" \
  -I "${BUILD_DIR}" -I "${PROJECT_ROOT}/exiv2/include" -I "${DEPS_INC}" \
  -L "${BUILD_DIR}/lib" -L "${DEPS_LIB}" \
  -lexiv2 -lbrotlidec -lbrotlicommon -lexpat -linireader -linih \
  -o "${DIST_DIR}/exiv2.js" \
  -sWASM=1 -sUSE_ZLIB=1 \
  -sMODULARIZE=1 -sEXPORT_NAME=createExiv2Module \
  -sALLOW_MEMORY_GROWTH=1 \
  --bind

if [[ -f "${DIST_DIR}/exiv2.js" && -f "${DIST_DIR}/exiv2.wasm" ]]; then
  ok "OK: ${DIST_DIR}/exiv2.js, ${DIST_DIR}/exiv2.wasm generated."
else
  warn "Wrapper outputs not found in ${DIST_DIR}. Check link step logs."
  exit 2
fi
