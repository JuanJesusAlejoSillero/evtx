#!/bin/bash
set -e

# Function to determine the default target
get_default_target() {
    case "$(uname -sm)" in
        "Darwin x86_64") echo "x86_64-apple-darwin" ;;
        "Darwin arm64") echo "aarch64-apple-darwin" ;;
        "Linux x86_64") echo "x86_64-unknown-linux-gnu" ;;
        "Linux aarch64") echo "aarch64-unknown-linux-gnu" ;;
        *) echo "unknown" ;;
    esac
}

# Use the provided TARGET or default to the current machine's target
TARGET=${TARGET:-$(get_default_target)}

if [ "$TARGET" = "unknown" ]; then
    echo "Error: Unable to determine default target. Please specify TARGET explicitly."
    exit 1
fi

echo "Using target: $TARGET"

echo "Building binary for instrumented run"
RUSTFLAGS="-Cprofile-generate=/tmp/pgo-data" \
    cargo build --release --target $TARGET --features fast-alloc

echo "Running instrumented binary"
for i in $(find samples -name "*.evtx"); do
    echo "Processing $i"
    ./target/$TARGET/release/evtx_dump -t 1 -o json $i 1>/dev/null 2>&1
    ./target/$TARGET/release/evtx_dump -t 1 -o xml $i 1>/dev/null 2>&1
    ./target/$TARGET/release/evtx_dump -t 8 -o json $i 1>/dev/null 2>&1
done

echo "Merging profile data"
llvm-profdata merge -o /tmp/pgo-data/merged.profdata /tmp/pgo-data

echo "Building binary with profile data"
RUSTFLAGS="-Cprofile-use=/tmp/pgo-data/merged.profdata" \
    cargo build --release --target $TARGET --features fast-alloc