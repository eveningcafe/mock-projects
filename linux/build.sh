#!/bin/bash
set -e

# Sync latest app files into package tree
cp pingapp/app.py pingapp/requirements.txt package/opt/pingpingapp/
cp pingapp/templates/index.html package/opt/pingpingapp/templates/

# Build the .deb
dpkg-deb --build package pingapp_1.0_amd64.deb

echo "Built: pingapp_1.0_amd64.deb"
echo ""
echo "Install with:"
echo "  sudo apt install ./pingapp_1.0_amd64.deb"
