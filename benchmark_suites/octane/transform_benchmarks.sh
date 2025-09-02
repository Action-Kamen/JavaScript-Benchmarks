#!/bin/bash
#
# This script transforms the original Octane benchmark files into
# standalone, runnable versions by prepending a header and appending
# a runner function call.

# --- Configuration ---
HEADER_FILE="octane_header.js"
OUTPUT_DIR="standalone"

# A hardcoded list of the Octane benchmark files to transform.
# We exclude files that aren't benchmarks, like the header itself.
BENCHMARK_FILES=(
    "box2d.js"
    "code-load.js"
    "crypto.js"
    "deltablue.js"
    "earley-boyer.js"
    # "gbemu-part1.js"
    # "gbemu-part2.js"
    "mandreel.js"
    "navier-stokes.js"
    "pdfjs.js"
    "raytrace.js"
    "regexp.js"
    "richards.js"
    "splay.js"
    # "typescript.js"
    # "zlib.js"
)

# --- Pre-flight Checks ---
# Check if the header file exists before we start.
if [ ! -f "$HEADER_FILE" ]; then
    echo "❌ Error: Header file '$HEADER_FILE' not found."
    echo "Please make sure the header file exists in this directory."
    exit 1
fi

# Create the output directory if it doesn't exist.
mkdir -p "$OUTPUT_DIR"
echo "✅ Output directory './$OUTPUT_DIR/' is ready."
echo ""


# --- Main Processing Loop ---
for original_file in "${BENCHMARK_FILES[@]}"; do
    # Check if the original file to be transformed exists.
    if [ ! -f "$original_file" ]; then
        echo "⚠️  Warning: Skipping '$original_file' because it was not found."
        continue
    fi

    # Construct the new filename, e.g., crypto.js -> standalone/crypto_standalone.js
    base_name=$(basename "$original_file" .js)
    output_file="$OUTPUT_DIR/${base_name}_standalone.js"

    echo "⚙️  Processing '$original_file'..."

    # Step 1: Concatenate the header and the original file content.
    cat "$HEADER_FILE" "$original_file" > "$output_file"

    # Step 2: Append the runner function call to the very end of the new file.
    echo "" >> "$output_file" # Add a newline for style.
    echo "// This line starts the benchmark after everything is defined." >> "$output_file"
    echo "runStandalone();" >> "$output_file"

    echo "    -> Created '$output_file'"
done

echo ""
echo "---"
echo "🎉 All benchmarks have been transformed successfully!"
echo "The new files are located in the './$OUTPUT_DIR/' directory."
echo "You can now run any of them directly. For example:"
echo "node $OUTPUT_DIR/navier-stokes_standalone.js"
echo "---"

# In your octane/ directory
cat octane_header.js gbemu-part2.js gbemu-part1.js > standalone/gbemu_standalone.js
echo "runStandalone();" >> standalone/gbemu_standalone.js

# In your octane/ directory
cat octane_header.js typescript-compiler.js typescript-input.js typescript.js > standalone/typescript_standalone.js
echo "runStandalone();" >> standalone/typescript_standalone.js

cat octane_header.js zlib-data.js zlib.js > standalone/zlib_standalone.js
echo "runStandalone();" >> standalone/zlib_standalone.js