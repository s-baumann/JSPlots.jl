#!/bin/bash
# JSPlots Launcher Script for Linux/macOS
# Tries browsers in order: Brave, Chrome, Firefox, then system default

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HTML_FILE="$SCRIPT_DIR/external_formats_examples.html"

# Create a temporary user data directory for Chromium-based browsers
TEMP_USER_DIR="$(mktemp -d)"

# Try Brave Browser
if command -v brave-browser &> /dev/null; then
    echo "Opening with Brave Browser..."
    brave-browser --allow-file-access-from-files --disable-web-security --user-data-dir="$TEMP_USER_DIR" "$HTML_FILE" &
    exit 0
elif command -v brave &> /dev/null; then
    echo "Opening with Brave Browser..."
    brave --allow-file-access-from-files --disable-web-security --user-data-dir="$TEMP_USER_DIR" "$HTML_FILE" &
    exit 0
fi

# Try Google Chrome
if command -v google-chrome &> /dev/null; then
    echo "Opening with Google Chrome..."
    google-chrome --allow-file-access-from-files --disable-web-security --user-data-dir="$TEMP_USER_DIR" "$HTML_FILE" &
    exit 0
elif command -v chrome &> /dev/null; then
    echo "Opening with Chrome..."
    chrome --allow-file-access-from-files --disable-web-security --user-data-dir="$TEMP_USER_DIR" "$HTML_FILE" &
    exit 0
fi

# Try Chromium
if command -v chromium-browser &> /dev/null; then
    echo "Opening with Chromium..."
    chromium-browser --allow-file-access-from-files --disable-web-security --user-data-dir="$TEMP_USER_DIR" "$HTML_FILE" &
    exit 0
elif command -v chromium &> /dev/null; then
    echo "Opening with Chromium..."
    chromium --allow-file-access-from-files --disable-web-security --user-data-dir="$TEMP_USER_DIR" "$HTML_FILE" &
    exit 0
fi

# Try Firefox
if command -v firefox &> /dev/null; then
    echo "Opening with Firefox..."
    firefox "$HTML_FILE" &
    exit 0
fi

# Fallback to default browser
echo "Opening with default browser..."
if command -v xdg-open &> /dev/null; then
    xdg-open "$HTML_FILE" &
elif command -v open &> /dev/null; then
    # macOS
    open "$HTML_FILE" &
else
    echo "Could not find a suitable browser. Please open $HTML_FILE manually."
    exit 1
fi
