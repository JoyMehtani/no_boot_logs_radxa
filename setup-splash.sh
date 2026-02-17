#!/bin/bash

# Find the splash image - adjust this path if needed
SPLASH_IMAGE="/home/rock/Book your ePoster Slot.png"

# If not found, look for any PNG in home directory
if [ ! -f "$SPLASH_IMAGE" ]; then
    SPLASH_IMAGE=$(find /home/rock -maxdepth 1 -name "*.png" | head -1)
fi

if [ ! -f "$SPLASH_IMAGE" ]; then
    echo "ERROR: No PNG image found in /home/rock/"
    echo "Please copy your splash image to /home/rock/ and run again"
    exit 1
fi

echo "Using image: $SPLASH_IMAGE"
# Standardize the name
cp "$SPLASH_IMAGE" "/home/rock/splash-image.png"
SPLASH_IMAGE="/home/rock/splash-image.png"

set -e

echo "=== ePoster Splash Setup Script ==="

# 1. Install required packages
echo "[1/7] Installing packages..."
sudo apt install -y feh wmctrl xdotool imagemagick


# 2. Update kernel cmdline
echo "[2/7] Updating kernel parameters..."

# Get current UUID and other params from existing cmdline, just update the flags
CURRENT_CMDLINE=$(cat /etc/kernel/cmdline)

# Remove old conflicting params and add our new ones
NEW_CMDLINE=$(echo "$CURRENT_CMDLINE" | \
    sed 's/loglevel=[0-9]*/loglevel=0/g' | \
    sed 's/console=tty[0-9]*/console=tty3/g' | \
    sed 's/fbcon=nodefer//g' | \
    sed 's/fbcon=map:[0-9]*//g' | \
    sed 's/vt.global_cursor_default=[0-9]*//g' | \
    sed 's/systemd.show_status=[a-z]*//g' | \
    sed 's/rd.systemd.show_status=[a-z]*//g' | \
    tr -s ' ')

# Append our new params
NEW_CMDLINE="$NEW_CMDLINE vt.global_cursor_default=0 rd.systemd.show_status=false systemd.show_status=false fbcon=nodefer fbcon=map:2"

echo "$NEW_CMDLINE" | sudo tee /etc/kernel/cmdline
echo "Kernel cmdline updated to:"
cat /etc/kernel/cmdline

# 3. Update extlinux.conf
echo "[3/7] Updating bootloader config..."
sudo chattr -i /boot/extlinux/extlinux.conf 2>/dev/null || true
sudo u-boot-update
sudo chattr +i /boot/extlinux/extlinux.conf

# 4. Create splash wrapper script
echo "[4/7] Creating splash wrapper..."
sudo tee /home/rock/splash-wrapper.sh << 'EOF'
#!/bin/bash
sleep 2
DISPLAY=:0 feh --scale-down --image-bg black --hide-pointer "/home/rock/splash-image.png" &
FEH_PID=$!
sleep 1
WID=$(DISPLAY=:0 xdotool search --name "Book your ePoster Slot")
DISPLAY=:0 wmctrl -i -r $WID -e 0,0,0,1440,900
DISPLAY=:0 wmctrl -i -r $WID -b add,fullscreen,above
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

# 5. Create autostart entry
echo "[5/7] Creating autostart entry..."
mkdir -p /home/rock/.config/autostart
tee /home/rock/.config/autostart/splash-image.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Splash Image
Exec=/home/rock/splash-wrapper.sh
X-KDE-autostart-phase=1
StartupNotify=false
EOF

# 6. Disable KDE splash screen
echo "[6/7] Disabling KDE splash..."
mkdir -p /home/rock/.config
tee /home/rock/.config/ksplashrc << 'EOF'
[KSplash]
Theme=None
Engine=none
EOF

# 7. Set Plymouth theme
echo "[7/7] Configuring Plymouth..."
sudo mkdir -p /usr/share/plymouth/themes/custom-splash
sudo tee /usr/share/plymouth/themes/custom-splash/custom-splash.plymouth << 'EOF'
[Plymouth Theme]
Name=Custom Splash
Description=Custom boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/custom-splash
ScriptFile=/usr/share/plymouth/themes/custom-splash/custom-splash.script
EOF

sudo tee /usr/share/plymouth/themes/custom-splash/custom-splash.script << 'EOF'
wallpaper_image = Image("splash.png");
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
scaled = wallpaper_image.Scale(screen_width, screen_height);
sprite = Sprite(scaled);
sprite.SetPosition(0, 0, 0);
EOF

sudo cp "/home/rock/splash-image.png" /usr/share/plymouth/themes/custom-splash/splash.png
sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/custom-splash/custom-splash.plymouth 100
sudo update-alternatives --set default.plymouth /usr/share/plymouth/themes/custom-splash/custom-splash.plymouth
sudo update-initramfs -u

echo ""
echo "=== Setup Complete! ==="
echo "Please make sure your splash image is at: /home/rock/splash-image.png"
echo "Then reboot to apply changes."
echo ""
read -p "Reboot now? (y/n): " choice
if [ "$choice" = "y" ]; then
    sudo reboot
fi
