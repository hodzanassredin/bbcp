#!/bin/bash
# Build 64-bit BlackBox boot image

BBROOT=~/sources/bbcp
BOOTLOADER="$BBROOT/Dev/Rsrc/bbrun64"
OUTIMG="$BBROOT/Dev/Rsrc/bb64.img"

# Copy boot loader as base
cp "$BOOTLOADER" "$OUTIMG"

# Pack OCF modules after the boot loader
# Module list: Kernel64 (must be first), then others
MODULES=(
    "$BBROOT/System/Code/Kernel64.ocf"
    "$BBROOT/System/Code/Utf.ocf"
    "$BBROOT/System/Code/Files.ocf"
    "$BBROOT/Lin/Code/Dates.ocf"
    "$BBROOT/Lin/Code/Dl.ocf"
    "$BBROOT/Lin/Code/Kernel64.ocf"
)

for ocf in "${MODULES[@]}"; do
    if [ -f "$ocf" ]; then
        cat "$ocf" >> "$OUTIMG"
        echo "  + $(basename $ocf) ($(stat -c%s $ocf) bytes)"
    else
        echo "  MISSING: $ocf"
    fi
done

echo "Boot image: $OUTIMG ($(stat -c%s $OUTIMG) bytes)"
