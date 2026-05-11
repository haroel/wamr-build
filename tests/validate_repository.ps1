Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

function Assert-FileExists {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath (Join-Path $root $Path) -PathType Leaf)) {
        throw "Missing file: $Path"
    }
}

function Assert-DirectoryExists {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath (Join-Path $root $Path) -PathType Container)) {
        throw "Missing directory: $Path"
    }
}

function Assert-Contains {
    param(
        [string] $Path,
        [string] $Needle
    )
    $fullPath = Join-Path $root $Path
    $content = Get-Content -LiteralPath $fullPath -Raw
    if (-not $content.Contains($Needle)) {
        throw "Expected '$Path' to contain '$Needle'"
    }
}

function Assert-NotExists {
    param([string] $Path)
    if (Test-Path -LiteralPath (Join-Path $root $Path)) {
        throw "Unexpected path exists: $Path"
    }
}

Assert-FileExists '.gitmodules'
Assert-Contains '.gitmodules' 'path = third_party/wasm-micro-runtime'
Assert-Contains '.gitmodules' 'url = https://github.com/bytecodealliance/wasm-micro-runtime.git'

Assert-DirectoryExists 'third_party/wasm-micro-runtime'
$tag = (& git -C (Join-Path $root 'third_party/wasm-micro-runtime') describe --tags --exact-match HEAD).Trim()
if ($tag -ne 'WAMR-2.4.4') {
    throw "Expected WAMR submodule tag WAMR-2.4.4, got '$tag'"
}

Assert-FileExists 'cmake/wamr-runtime/CMakeLists.txt'
Assert-Contains 'cmake/wamr-runtime/CMakeLists.txt' 'WAMR_BUILD_PLATFORM "darwin"'
Assert-Contains 'cmake/wamr-runtime/CMakeLists.txt' 'WAMR_BUILD_TARGET "AARCH64"'
Assert-Contains 'cmake/wamr-runtime/CMakeLists.txt' 'WAMR_BUILD_INTERP 1'
Assert-Contains 'cmake/wamr-runtime/CMakeLists.txt' 'WAMR_BUILD_FAST_INTERP 1'
Assert-Contains 'cmake/wamr-runtime/CMakeLists.txt' 'WAMR_BUILD_AOT 0'
Assert-Contains 'cmake/wamr-runtime/CMakeLists.txt' 'WAMR_BUILD_JIT 0'
Assert-Contains 'cmake/wamr-runtime/CMakeLists.txt' 'WAMR_BUILD_FAST_JIT 0'
Assert-Contains 'cmake/wamr-runtime/CMakeLists.txt' 'add_library(iwasm STATIC'
Assert-Contains 'cmake/wamr-runtime/CMakeLists.txt' 'build-scripts/runtime_lib.cmake'

Assert-FileExists 'scripts/build_wamr_apple.sh'
Assert-Contains 'scripts/build_wamr_apple.sh' 'WAMR-2.4.4'
Assert-Contains 'scripts/build_wamr_apple.sh' 'iphoneos'
Assert-Contains 'scripts/build_wamr_apple.sh' 'iphonesimulator'
Assert-Contains 'scripts/build_wamr_apple.sh' 'macosx'
Assert-Contains 'scripts/build_wamr_apple.sh' 'xcodebuild -create-xcframework'
Assert-Contains 'scripts/build_wamr_apple.sh' 'wamr.xcframework'
Assert-Contains 'scripts/build_wamr_apple.sh' '${XCFRAMEWORK_PATH}/include'
$appleBuildScript = Get-Content -LiteralPath (Join-Path $root 'scripts/build_wamr_apple.sh') -Raw
if ($appleBuildScript.Contains('-d "${WAMR_ROOT}/.git"')) {
    throw 'scripts/build_wamr_apple.sh must not require the submodule .git path to be a directory'
}
if ($appleBuildScript.Contains('iwasm.xcframework')) {
    throw 'scripts/build_wamr_apple.sh must generate wamr.xcframework, not iwasm.xcframework'
}
Assert-Contains 'scripts/build_wamr_apple.sh' 'git -C "${WAMR_ROOT}" rev-parse --is-inside-work-tree'
Assert-NotExists 'scripts/build_wamr.bat'

Assert-FileExists '.github/workflows/release-apple.yml'
Assert-Contains '.github/workflows/release-apple.yml' 'push:'
Assert-Contains '.github/workflows/release-apple.yml' 'contents: write'
Assert-Contains '.github/workflows/release-apple.yml' './scripts/build_wamr_apple.sh'
Assert-Contains '.github/workflows/release-apple.yml' 'gh release create'
Assert-Contains '.github/workflows/release-apple.yml' 'dist/apple/wamr.xcframework.zip'

Assert-Contains 'docs/main.md' 'WAMR-2.4.4'
Assert-Contains 'docs/main.md' 'Apple 平台'
Assert-Contains 'docs/main.md' 'third_party/wasm-micro-runtime'
Assert-Contains 'docs/main.md' 'wamr.xcframework'
Assert-Contains 'docs/main.md' 'wamr.xcframework/include'

Write-Output 'Repository validation passed.'
