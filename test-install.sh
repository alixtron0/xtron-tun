#!/bin/bash

echo "=== Testing install.sh with DEBUG mode ==="
echo ""
echo "This will run the installer with full debugging enabled"
echo "Log file will be saved to: /tmp/xtron-install.log"
echo ""
read -p "Press Enter to continue (Ctrl+C to cancel)..."

# Run with debug mode
DEBUG=1 bash install.sh 2>&1 | tee /tmp/xtron-install-output.log

echo ""
echo "=== Installation Complete ==="
echo "Output saved to: /tmp/xtron-install-output.log"
echo "Background log: /tmp/xtron-install.log"
echo ""
echo "Check logs with:"
echo "  cat /tmp/xtron-install-output.log"
echo "  cat /tmp/xtron-install.log"
