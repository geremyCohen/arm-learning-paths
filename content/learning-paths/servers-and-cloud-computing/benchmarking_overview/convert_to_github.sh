#!/bin/bash

# Function to convert Hugo markdown to GitHub markdown
convert_file() {
    local input_file="$1"
    local output_file="$2"
    
    # Skip frontmatter (everything between first --- and second ---)
    awk '
    BEGIN { in_frontmatter = 0; found_first = 0 }
    /^---$/ { 
        if (!found_first) {
            found_first = 1
            in_frontmatter = 1
            next
        } else if (in_frontmatter) {
            in_frontmatter = 0
            next
        }
    }
    !in_frontmatter { 
        # Convert Hugo shortcodes to GitHub markdown
        gsub(/\{\{\% notice tip \%\}\}/, "> **💡 Tip**:")
        gsub(/\{\{\% notice note \%\}\}/, "> **📝 Note**:")
        gsub(/\{\{\% notice info \%\}\}/, "> **ℹ️ Info**:")
        gsub(/\{\{\% notice warning \%\}\}/, "> **⚠️ Warning**:")
        gsub(/\{\{\% \/notice \%\}\}/, "")
        
        # Convert internal links
        gsub(/\.\.\/([^\/]+)\//, "./")
        gsub(/\]\(\.\/([^)]+)\/\)/, "](./\1.md)")
        
        print
    }
    ' "$input_file" > "$output_file"
}

# Convert each file
convert_file "baseline.md" "/Users/gercoh01/kustomer/arm_benchmarking/03-baseline.md"
convert_file "compiler-optimizations.md" "/Users/gercoh01/kustomer/arm_benchmarking/04-compiler-optimizations.md"
convert_file "simd-optimizations.md" "/Users/gercoh01/kustomer/arm_benchmarking/05-simd-optimizations.md"
convert_file "memory-optimizations.md" "/Users/gercoh01/kustomer/arm_benchmarking/06-memory-optimizations.md"
convert_file "concurrency-optimizations.md" "/Users/gercoh01/kustomer/arm_benchmarking/07-concurrency-optimizations.md"
convert_file "system-optimizations.md" "/Users/gercoh01/kustomer/arm_benchmarking/08-system-optimizations.md"
convert_file "profiling-analysis.md" "/Users/gercoh01/kustomer/arm_benchmarking/09-profiling-analysis.md"
convert_file "performance-analysis.md" "/Users/gercoh01/kustomer/arm_benchmarking/10-performance-analysis.md"

echo "Conversion complete!"
