#!/bin/bash
set -e

VERSION=${1:-"1.0.0"}
APP="FinancePro"
OUTDIR="dist"

echo "==> Building Flutter Linux release..."
cd frontend
flutter build linux --release
cd ..

BUILD_DIR="frontend/build/linux/x64/release/bundle"
mkdir -p "$OUTDIR"

# ── TAR.GZ ────────────────────────────────────────────────────────────────────
echo "==> Creating TAR.GZ..."
tar -czf "$OUTDIR/${APP}-${VERSION}-linux-x64.tar.gz" -C "$BUILD_DIR" .
echo "    $OUTDIR/${APP}-${VERSION}-linux-x64.tar.gz"

# ── AppImage ──────────────────────────────────────────────────────────────────
if command -v appimagetool &>/dev/null; then
    echo "==> Creating AppImage..."
    APPDIR="$OUTDIR/AppDir"
    rm -rf "$APPDIR"
    mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/256x256/apps"

    cp -r "$BUILD_DIR/." "$APPDIR/usr/bin/"

    cat > "$APPDIR/financepro.desktop" << DESKTOP
[Desktop Entry]
Name=FinancePro
Exec=financepro
Icon=financepro
Type=Application
Categories=Finance;
DESKTOP

    cat > "$APPDIR/AppRun" << 'APPRUN'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/financepro" "$@"
APPRUN
    chmod +x "$APPDIR/AppRun"

    # placeholder icon if none exists
    if [ ! -f "$APPDIR/usr/share/icons/hicolor/256x256/apps/financepro.png" ]; then
        cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/financepro.png" \
           "$APPDIR/financepro.png" 2>/dev/null || \
        convert -size 256x256 xc:#1976D2 -fill white -gravity Center \
            -pointsize 48 -annotate 0 "FP" "$APPDIR/financepro.png" 2>/dev/null || \
        touch "$APPDIR/financepro.png"
    fi

    ARCH=x86_64 appimagetool "$APPDIR" "$OUTDIR/${APP}-${VERSION}-linux-x86_64.AppImage"
    rm -rf "$APPDIR"
    echo "    $OUTDIR/${APP}-${VERSION}-linux-x86_64.AppImage"
else
    echo "    [skip] appimagetool not found. Install: https://github.com/AppImage/appimagetool/releases"
fi

# ── DEB ───────────────────────────────────────────────────────────────────────
if command -v dpkg-deb &>/dev/null; then
    echo "==> Creating DEB package..."
    DEBDIR="$OUTDIR/deb"
    rm -rf "$DEBDIR"
    mkdir -p "$DEBDIR/DEBIAN" \
             "$DEBDIR/usr/lib/financepro" \
             "$DEBDIR/usr/bin" \
             "$DEBDIR/usr/share/applications"

    cp -r "$BUILD_DIR/." "$DEBDIR/usr/lib/financepro/"

    cat > "$DEBDIR/usr/bin/financepro" << 'STUB'
#!/bin/bash
exec /usr/lib/financepro/financepro "$@"
STUB
    chmod +x "$DEBDIR/usr/bin/financepro"

    cat > "$DEBDIR/usr/share/applications/financepro.desktop" << DESKTOP
[Desktop Entry]
Name=FinancePro
Exec=financepro
Icon=financepro
Type=Application
Categories=Finance;
DESKTOP

    cat > "$DEBDIR/DEBIAN/control" << CONTROL
Package: financepro
Version: ${VERSION}
Architecture: amd64
Maintainer: Tolib
Description: Personal finance tracking platform with AI
 Self-hosted finance tracker with multi-currency support,
 AI categorization, receipt OCR, and analytics.
CONTROL

    dpkg-deb --build "$DEBDIR" "$OUTDIR/${APP}-${VERSION}-amd64.deb"
    rm -rf "$DEBDIR"
    echo "    $OUTDIR/${APP}-${VERSION}-amd64.deb"
else
    echo "    [skip] dpkg-deb not found (not Debian/Ubuntu)"
fi

echo ""
echo "Done! Files in ./$OUTDIR/"
ls -lh "$OUTDIR/"
