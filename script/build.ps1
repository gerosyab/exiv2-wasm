param([switch]$Clean)

$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot | Split-Path -Parent
$buildDir = Join-Path $projectRoot "build"
$distDir = Join-Path $projectRoot "dist"
if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }

$depPrefix = Join-Path $projectRoot "deps\install"
$depInc    = Join-Path $depPrefix "include"
$depLib    = Join-Path $depPrefix "lib"

$expatSrc   = Join-Path $projectRoot "libexpat\expat"
$expatBuild = Join-Path $buildDir "build-expat"

$brotliSrc   = Join-Path $projectRoot "brotli"
$brotliBuild = Join-Path $buildDir "build-brotli"

$inihSrc   = Join-Path $projectRoot "inih"
# inih는 수동 컴파일로 처리

$outJs = Join-Path $distDir "exiv2.js"

Write-Host "=== exiv2-wasm build ==="

if ($Clean) {
  Write-Host "[Clean] removing outputs..."
  @($buildDir, $depPrefix, $expatBuild, $brotliBuild) | % { if (Test-Path $_) { Remove-Item $_ -Recurse -Force } }
}

function Need($cmd,$hint){ if(-not (Get-Command $cmd -ErrorAction SilentlyContinue)){ throw "$cmd not found. $hint" } }
if (-not (Get-Command emcc -ErrorAction SilentlyContinue)) {
  if ($env:EMSDK -and (Test-Path (Join-Path $env:EMSDK "emsdk_env.ps1"))) { & (Join-Path $env:EMSDK "emsdk_env.ps1") }
  else { throw "emcc not found. Activate emsdk first (.\emsdk_env.ps1)" }
}
Need emcmake "Activate emsdk"
Need cmake   "Install CMake"
Need ninja   "Install Ninja"
Need emar    "Emscripten archiver emar required"

@($buildDir,$depPrefix,$depInc,$depLib) | % { if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ | Out-Null } }

# 1) EXPAT
$expatA = Join-Path $depLib "libexpat.a"
if (-not (Test-Path $expatA)) {
  if (-not (Test-Path $expatSrc)) { throw "libexpat source missing at $expatSrc" }
  emcmake cmake -S "$expatSrc" -B "$expatBuild" -G Ninja `
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$depPrefix" `
    -DBUILD_SHARED_LIBS=OFF -DEXPAT_BUILD_TOOLS=OFF -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_EXAMPLES=OFF
  cmake --build "$expatBuild" --target install --parallel
}

# 2) Brotli (manual install: common+dec)
$brotliCommonA = Join-Path $depLib "libbrotlicommon.a"
$brotliDecA    = Join-Path $depLib "libbrotlidec.a"
if (-not (Test-Path $brotliCommonA) -or -not (Test-Path $brotliDecA)) {
  if (-not (Test-Path $brotliSrc)) { throw "brotli source missing at $brotliSrc" }
  emcmake cmake -S "$brotliSrc" -B "$brotliBuild" -G Ninja `
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_TOOLS=OFF -DBROTLI_DISABLE_TESTS=ON `
    -DCMAKE_INSTALL_PREFIX="$depPrefix"
  cmake --build "$brotliBuild" --target brotlicommon --parallel
  cmake --build "$brotliBuild" --target brotlidec    --parallel
  $bCommon = Get-ChildItem $brotliBuild -Recurse -Filter libbrotlicommon.a | Select-Object -First 1
  $bDec    = Get-ChildItem $brotliBuild -Recurse -Filter libbrotlidec.a    | Select-Object -First 1
  if (-not $bCommon -or -not $bDec) { throw "brotli libs not found after build" }
  Copy-Item -Force $bCommon.FullName $brotliCommonA
  Copy-Item -Force $bDec.FullName    $brotliDecA
  $hdrSrc = Join-Path $brotliSrc "c\include\brotli"
  $hdrDst = Join-Path $depInc "brotli"
  if (-not (Test-Path $hdrDst)) { New-Item -ItemType Directory -Path $hdrDst | Out-Null }
  Copy-Item -Recurse -Force (Join-Path $hdrSrc "*") $hdrDst
}

# 3) INIH (manual build)
$inihA      = Join-Path $depLib "libinih.a"
$iniReaderA = Join-Path $depLib "libinireader.a"
if (-not (Test-Path $inihA) -or -not (Test-Path $iniReaderA)) {
  if (-not (Test-Path $inihSrc)) { throw "inih source missing at $inihSrc" }
  $ini_c = Join-Path $inihSrc "ini.c"
  $ini_h = Join-Path $inihSrc "ini.h"
  $iniread_cpp = Join-Path $inihSrc "cpp\INIReader.cpp"
  $iniread_h   = Join-Path $inihSrc "cpp\INIReader.h"
  if (-not (Test-Path $ini_c)) { throw "ini.c missing" }
  if (-not (Test-Path $iniread_cpp)) { throw "INIReader.cpp missing" }
  Copy-Item -Force $ini_h (Join-Path $depInc "ini.h")
  Copy-Item -Force $iniread_h (Join-Path $depInc "INIReader.h")
  Push-Location $depPrefix\..
  emcc -O2 -I "$depInc" -I "$inihSrc" -c "$ini_c" -o "ini.o"
  em++ -O2 -I "$depInc" -I "$inihSrc" -c "$iniread_cpp" -o "INIReader.o"
  emar rcs "$inihA" "ini.o"
  emar rcs "$iniReaderA" "INIReader.o"
  Remove-Item "ini.o","INIReader.o" -Force
  Pop-Location
}

# 4) Configure Exiv2
$EXPATH = $depInc
$EXLIB  = Join-Path $depLib "libexpat.a"
$BRINC  = $depInc
$BRDEC  = Join-Path $depLib "libbrotlidec.a"
$BRCOM  = Join-Path $depLib "libbrotlicommon.a"
$INIH_INC = $depInc
$INIH_LIB = $inihA
$INIR_LIB = $iniReaderA

emcmake cmake -S "$projectRoot\exiv2" -B "$buildDir" -G Ninja `
  -DBUILD_SHARED_LIBS=OFF -DEXIV2_ENABLE_NLS=OFF -DEXIV2_ENABLE_VIDEO=OFF -DEXIV2_ENABLE_WEBREADY=OFF `
  -DEXIV2_ENABLE_CURL=OFF -DEXIV2_BUILD_SAMPLES=OFF -DEXIV2_BUILD_UNIT_TESTS=OFF -DEXIV2_ENABLE_BMFF=ON `
  -DEXIV2_BUILD_EXIV2_COMMAND=OFF `
  -DCMAKE_BUILD_TYPE=Release `
  -DEXPAT_INCLUDE_DIR="$EXPATH" -DEXPAT_LIBRARY="$EXLIB" `
  -DBROTLI_INCLUDE_DIR="$BRINC" -DBROTLIDEC_LIBRARY="$BRDEC" -DBROTLICOMMON_LIBRARY="$BRCOM" `
  -Dinih_INCLUDE_DIR="$INIH_INC" -Dinih_LIBRARY="$INIH_LIB" -Dinih_inireader_INCLUDE_DIR="$INIH_INC" -Dinih_inireader_LIBRARY="$INIR_LIB"

cmake --build "$buildDir" --parallel

# 5) Link wrapper.cpp -> exiv2.js/wasm
$wrapper = Join-Path $projectRoot "wrapper.cpp"
if (-not (Test-Path $wrapper)) { throw "wrapper.cpp missing" }

Push-Location $buildDir
em++ -O3 "$wrapper" `
  -I "$buildDir" -I "$projectRoot\exiv2\include" -I "$depInc" `
  -L "$buildDir\lib" -L "$depLib" `
  -lexiv2 -lbrotlidec -lbrotlicommon -lexpat -linireader -linih `
  -o "$outJs" `
  -sWASM=1 -sUSE_ZLIB=1 -sMODULARIZE=1 -sEXPORT_NAME=createExiv2Module -sALLOW_MEMORY_GROWTH=1 --bind
Pop-Location

$outWasm = Join-Path $distDir "exiv2.wasm"
if ((Test-Path $outJs) -and (Test-Path $outWasm)) {
  Write-Host "OK: $outJs, $outWasm generated."
} else {
  Write-Warning "Wrapper outputs not found in $distDir. Check link step above."
}