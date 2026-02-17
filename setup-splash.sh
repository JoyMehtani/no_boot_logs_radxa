#!/bin/bash

# Find the splash image
SPLASH_IMAGE="/home/rock/Book your ePoster Slot.png"

# If not found, look for any PNG in home directory or subdirectory
if [ ! -f "$SPLASH_IMAGE" ]; then
    SPLASH_IMAGE=$(find /home/rock -maxdepth 2 -name "*.png" | head -1)
fi

if [ ! -f "$SPLASH_IMAGE" ]; then
    echo "ERROR: No PNG image found in /home/rock/"
    echo "Please copy your splash image to /home/rock/ and run again"
    exit 1
fi

echo "Using image: $SPLASH_IMAGE"

# Standardize the name - always copy to this fixed path
cp "$SPLASH_IMAGE" "/home/rock/Book your ePoster Slot.png"
SPLASH_IMAGE="/home/rock/Book your ePoster Slot.png"

set -e

echo "=== ePoster Splash Setup Script ==="

# 1. Install required packages
echo "[1/5] Installing packages..."
sudo apt install -y feh wmctrl xdotool

# 2. Update kernel cmdline (preserves device-specific UUID)
echo "[2/5] Updating kernel parameters..."
CURRENT_CMDLINE=$(cat /etc/kernel/cmdline)
NEW_CMDLINE=$(echo "$CURRENT_CMDLINE" | \
    sed 's/loglevel=[0-9]*/loglevel=0/g' | \
    sed 's/console=tty[0-9]*/console=tty3/g' | \
    sed 's/fbcon=nodefer//g' | \
    sed 's/fbcon=map:[0-9]*//g' | \
    sed 's/vt\.global_cursor_default=[0-9]*//g' | \
    sed 's/systemd\.show_status=[a-z]*//g' | \
    sed 's/rd\.systemd\.show_status=[a-z]*//g' | \
    tr -s ' ')
NEW_CMDLINE="$NEW_CMDLINE vt.global_cursor_default=0 rd.systemd.show_status=false systemd.show_status=false fbcon=nodefer fbcon=map:2"
echo "$NEW_CMDLINE" | sudo tee /etc/kernel/cmdline
echo "Kernel cmdline updated to:"
cat /etc/kernel/cmdline

# 3. Update extlinux.conf
echo "[3/5] Updating bootloader config..."
sudo chattr -i /boot/extlinux/extlinux.conf 2>/dev/null || true
sudo u-boot-update
sudo chattr +i /boot/extlinux/extlinux.conf

# 4. Create splash wrapper script
echo "[4/5] Creating splash wrapper..."
cat > /home/rock/splash-wrapper.sh << 'EOF'
#!/bin/bash
sleep 2

DISPLAY=:0 feh --scale-down --image-bg black --hide-pointer "/home/rock/Book your ePoster Slot.png" &
FEH_PID=$!

sleep 1

WID=$(DISPLAY=:0 xdotool search --name "Book your ePoster Slot")
if [ -n "$WID" ]; then
    DISPLAY=:0 wmctrl -i -r $WID -e 0,0,0,1440,900
    DISPLAY=:0 wmctrl -i -r $WID -b add,fullscreen,above
fi

while ! pgrep -f "RunThis.py" > /dev/null; do
    sleep 1
done

while ! pgrep -f "chromium-bin" > /dev/null; do
    sleep 1
done

sleep 5
kill $FEH_PID 2>/dev/null
pkill -f feh 2>/dev/null
EOF
chmod +x /home/rock/splash-wrapper.sh

# 5. Create autostart entry and disable KDE splash
echo "[5/5] Creating autostart entry and disabling KDE splash..."
mkdir -p /home/rock/.config/autostart
cat > /home/rock/.config/autostart/splash-image.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Splash Image
Exec=/home/rock/splash-wrapper.sh
X-KDE-autostart-phase=1
StartupNotify=false
EOF

mkdir -p /home/rock/.config
cat > /home/rock/.config/ksplashrc << 'EOF'
[KSplash]
Theme=None
Engine=none
EOF

echo ""
echo "=== Setup Complete! ==="
echo ""
read -p "Reboot now? (y/n): " choice
if [ "$choice" = "y" ]; then
    sudo reboot
fi
