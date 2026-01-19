#!/bin/bash
# Test script for Tomcat upgrade/downgrade functionality
set -e

echo "=== Tomcat Upgrade/Downgrade Test ==="
echo ""

# Version configurations
OLD_VERSION="9.0.113"
NEW_VERSION="9.0.120"

echo "Step 1: Destroy any existing instance"
rbenv exec kitchen destroy upgrade-win11 2>/dev/null || true

echo ""
echo "Step 2: Create VM"
rbenv exec kitchen create upgrade-win11

echo ""
echo "Step 3: Install Tomcat ${OLD_VERSION} (initial installation)"
TOMCAT_VERSION=${OLD_VERSION} rbenv exec kitchen converge upgrade-win11

echo ""
echo "Step 4: Verify initial installation"
rbenv exec kitchen verify upgrade-win11

echo ""
echo "Step 5: Upgrade to Tomcat ${NEW_VERSION}"
TOMCAT_VERSION=${NEW_VERSION} rbenv exec kitchen converge upgrade-win11

echo ""
echo "Step 6: Verify upgrade"
rbenv exec kitchen verify upgrade-win11

echo ""
echo "Step 7 (Optional): Downgrade back to ${OLD_VERSION}"
read -p "Do you want to test downgrade? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    TOMCAT_VERSION=${OLD_VERSION} rbenv exec kitchen converge upgrade-win11
    echo ""
    echo "Step 8: Verify downgrade"
    rbenv exec kitchen verify upgrade-win11
fi

echo ""
echo "=== Test Complete ==="
echo ""
echo "To check the VM state, run:"
echo "  rbenv exec kitchen login upgrade-win11"
echo ""
echo "To destroy the VM, run:"
echo "  rbenv exec kitchen destroy upgrade-win11"
