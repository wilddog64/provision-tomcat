#!/usr/bin/env python3
"""
Convert asciinema v3 format to v2 format.

svg-term-cli only supports v1 and v2 formats. This script converts v3 recordings
to v2 so they can be used with svg-term to generate animated SVGs.

Usage:
    ./asciinema-v3-to-v2.py input.cast output.cast
    ./asciinema-v3-to-v2.py input.cast  # outputs to stdout
"""

import json
import sys


def convert_v3_to_v2(input_file, output_file=None):
    """Convert asciinema v3 format to v2 format."""

    with open(input_file, 'r') as f:
        lines = f.readlines()

    if not lines:
        print("Error: Empty file", file=sys.stderr)
        sys.exit(1)

    # Parse header (first line)
    header = json.loads(lines[0])

    if header.get('version') != 3:
        print(f"Warning: File is version {header.get('version')}, not v3", file=sys.stderr)

    # Convert v3 header to v2 header
    v2_header = {
        'version': 2,
        'width': header.get('term', {}).get('cols', 80),
        'height': header.get('term', {}).get('rows', 24),
    }

    # Copy optional fields
    if 'timestamp' in header:
        v2_header['timestamp'] = header['timestamp']
    if 'idle_time_limit' in header:
        v2_header['idle_time_limit'] = header['idle_time_limit']
    if 'env' in header:
        v2_header['env'] = header['env']
    if 'title' in header:
        v2_header['title'] = header['title']

    # Build output
    output_lines = [json.dumps(v2_header)]

    # Event lines remain the same format in v2 and v3
    for line in lines[1:]:
        line = line.strip()
        if line:
            output_lines.append(line)

    output_content = '\n'.join(output_lines) + '\n'

    if output_file:
        with open(output_file, 'w') as f:
            f.write(output_content)
        print(f"Converted: {input_file} -> {output_file}", file=sys.stderr)
    else:
        print(output_content, end='')


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    convert_v3_to_v2(input_file, output_file)


if __name__ == '__main__':
    main()
