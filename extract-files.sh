#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=chime
VENDOR=xiaomi

export DEVICE_BRINGUP_YEAR=2025

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

export TARGET_ENABLE_CHECKELF=true

# If XML files don't have comments before the XML header, use this flag
# Can still be used with broken XML files by using blob_fixup
export TARGET_DISABLE_XML_FIXING=true

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

SECTION=
KANG=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-common)
            ONLY_COMMON=true
            ;;
        --only-firmware)
            ONLY_FIRMWARE=true
            ;;
        --only-target)
            ONLY_TARGET=true
            ;;
        -n | --no-cleanup)
            CLEAN_VENDOR=false
            ;;
        -k | --kang)
            KANG="--kang"
            ;;
        -s | --section)
            SECTION="${2}"
            shift
            CLEAN_VENDOR=false
            ;;
        *)
            SRC="${1}"
            ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        vendor/etc/seccomp_policy/vendor.qti.hardware.dsp.policy)
            echo 'madvise: 1' >> ${2}
            ;;
        vendor/lib64/libril-qc-hal-qmi.so)
            for v in 1.{0..2}; do
                sed -i "s|android.hardware.radio.config@${v}.so|android.hardware.radio.c_shim@${v}.so|g" "${2}"
            done
            ;;
        vendor/lib64/libwvhidl.so)
            "${PATCHELF}" --replace-needed "libcrypto.so" "libcrypto-v33.so" "${2}"
            ;;
        vendor/etc/camera/camxoverridesettings.txt)
            [ "$2" = "" ] && return 0
            sed -i "s/0x10080/0/" "${2}"
            sed -i "s/0x1F/0x0/" "${2}"
            ;;
    esac
}
function blob_fixup() {
    case "${1}" in
        vendor/etc/seccomp_policy/vendor.qti.hardware.dsp.policy)
            [ "$2" = "" ] && return 0
            echo 'madvise: 1' >> ${2}
            ;;
        vendor/lib64/libril-qc-hal-qmi.so)
            [ "$2" = "" ] && return 0
            for v in 1.{0..2}; do
                sed -i "s|android.hardware.radio.config@${v}.so|android.hardware.radio.c_shim@${v}.so|g" "${2}"
            done
            ;;
        vendor/lib64/libwvhidl.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libcrypto.so" "libcrypto-v33.so" "${2}"
            ;;
        vendor/etc/camera/camxoverridesettings.txt)
            [ "$2" = "" ] && return 0
            sed -i "s/0x10080/0/" "${2}"
            sed -i "s/0x1F/0x0/" "${2}"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}


function blob_fixup_dry() {
    blob_fixup "$1" ""
}

# Initialize the helper for common device
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files-recovery.txt" "${SRC}" \
        "${KANG}" --section "${SECTION}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" \
        "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"