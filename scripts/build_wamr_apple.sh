#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAMR_TAG="${WAMR_TAG:-WAMR-2.4.4}"
WAMR_SUBMODULE_PATH="third_party/wasm-micro-runtime"
WAMR_ROOT="${WAMR_ROOT:-${ROOT_DIR}/${WAMR_SUBMODULE_PATH}}"
BUILD_ROOT="${BUILD_ROOT:-${ROOT_DIR}/build/apple}"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist/apple}"
IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-11.0}"
MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-11.0}"

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "error: required tool '$1' was not found in PATH" >&2
        exit 1
    fi
}

require_tool git
require_tool cmake
require_tool xcodebuild
require_tool xcrun

is_wamr_checkout() {
    git -C "${WAMR_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: Apple XCFramework builds must run on macOS." >&2
    exit 1
fi

if ! is_wamr_checkout && [[ "${WAMR_ROOT}" == "${ROOT_DIR}/${WAMR_SUBMODULE_PATH}" ]]; then
    git -C "${ROOT_DIR}" submodule update --init --recursive -- "${WAMR_SUBMODULE_PATH}"
fi

if ! is_wamr_checkout; then
    echo "error: WAMR submodule is missing at ${WAMR_ROOT}" >&2
    exit 1
fi

git -C "${WAMR_ROOT}" fetch --tags --force origin "refs/tags/${WAMR_TAG}:refs/tags/${WAMR_TAG}"
git -C "${WAMR_ROOT}" checkout --detach "${WAMR_TAG}"

actual_tag="$(git -C "${WAMR_ROOT}" describe --tags --exact-match HEAD)"
if [[ "${actual_tag}" != "${WAMR_TAG}" ]]; then
    echo "error: expected WAMR tag ${WAMR_TAG}, got ${actual_tag}" >&2
    exit 1
fi

rm -rf "${BUILD_ROOT}" "${DIST_DIR}"
mkdir -p "${BUILD_ROOT}" "${DIST_DIR}"

build_slice() {
    local name="$1"
    local system_name="$2"
    local sdk_name="$3"
    local deployment_target="$4"
    local sdk_path
    local build_dir="${BUILD_ROOT}/${name}"
    local install_dir="${BUILD_ROOT}/install/${name}"

    sdk_path="$(xcrun --sdk "${sdk_name}" --show-sdk-path)"

    cmake \
        -S "${ROOT_DIR}/cmake/wamr-runtime" \
        -B "${build_dir}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SYSTEM_NAME="${system_name}" \
        -DCMAKE_OSX_SYSROOT="${sdk_path}" \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${deployment_target}" \
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_INSTALL_PREFIX="${install_dir}" \
        -DWAMR_ROOT_DIR="${WAMR_ROOT}"

    cmake --build "${build_dir}" --config Release --parallel
    cmake --install "${build_dir}" --config Release
}

build_slice "ios-arm64" "iOS" "iphoneos" "${IOS_DEPLOYMENT_TARGET}"
build_slice "ios-arm64-simulator" "iOS" "iphonesimulator" "${IOS_DEPLOYMENT_TARGET}"
build_slice "macos-arm64" "Darwin" "macosx" "${MACOS_DEPLOYMENT_TARGET}"

XCFRAMEWORK_PATH="${DIST_DIR}/wamr.xcframework"
rm -rf "${XCFRAMEWORK_PATH}"

xcodebuild -create-xcframework \
    -library "${BUILD_ROOT}/install/ios-arm64/lib/libiwasm.a" \
    -headers "${BUILD_ROOT}/install/ios-arm64/include" \
    -library "${BUILD_ROOT}/install/ios-arm64-simulator/lib/libiwasm.a" \
    -headers "${BUILD_ROOT}/install/ios-arm64-simulator/include" \
    -library "${BUILD_ROOT}/install/macos-arm64/lib/libiwasm.a" \
    -headers "${BUILD_ROOT}/install/macos-arm64/include" \
    -output "${XCFRAMEWORK_PATH}"

rm -rf "${XCFRAMEWORK_PATH}/include"
cmake -E copy_directory "${BUILD_ROOT}/install/ios-arm64/include" "${XCFRAMEWORK_PATH}/include"

ditto -c -k --keepParent "${XCFRAMEWORK_PATH}" "${DIST_DIR}/wamr.xcframework.zip"

echo "Built ${XCFRAMEWORK_PATH}"
echo "Headers copied to ${XCFRAMEWORK_PATH}/include"
echo "Packaged ${DIST_DIR}/wamr.xcframework.zip"
