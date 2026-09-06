#!/usr/bin/env bash
# ==============================================================================
# Samsung Galaxy Book3 Ultra Webcam 1080p Driver & Color Tuning Installer
# Target: Intel IPU6 (8086:a75d) + OmniVision OV02C10 Sensor (KBFC645)
# ==============================================================================

set -e

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${BOLD}${CYAN}================================================================${RESET}"
echo -e "${BOLD}${CYAN} Samsung Galaxy Book3 Ultra Webcam 1080p & Tuning Setup         ${RESET}"
echo -e "${BOLD}${CYAN}================================================================${RESET}\n"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LOCAL_OEM_DIR="$SCRIPT_DIR/oem_camera_files"
# Determine calibration source
if [ -d "$LOCAL_OEM_DIR" ] && [ -f "$LOCAL_OEM_DIR/OV02C10_KBFC645_ADL.aiqb" ]; then
    SRC_DIR="$LOCAL_OEM_DIR"
    echo -e " ${GREEN}✔ Using self-contained local OEM calibration files from $LOCAL_OEM_DIR${RESET}"
else
    SRC_DIR=""
fi

# Check root/sudo permissions for system edits
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Notice: Re-running script with sudo privileges...${RESET}"
    exec sudo "$0" "$@"
fi

# 1. Update v4l2loopback kernel module resolution limits to 1080p
echo -e "${BOLD}[1/6] Configuring v4l2loopback kernel module parameters...${RESET}"
if [ -f "/etc/modprobe.d/v4l2loopback.conf" ]; then
    sed -i "s/max_width=[0-9]*/max_width=1920/" /etc/modprobe.d/v4l2loopback.conf
    sed -i "s/max_height=[0-9]*/max_height=1080/" /etc/modprobe.d/v4l2loopback.conf
    echo -e " ${GREEN}✔ Updated /etc/modprobe.d/v4l2loopback.conf to 1920x1080${RESET}"
fi

# 2. Update v4l2-relayd daemon resolution, ISP quality tuning & un-mirroring parameters
echo -e "\n${BOLD}[2/6] Configuring v4l2-relayd daemon & ISP quality parameters...${RESET}"
for cfg in "/etc/default/v4l2-relayd" "/etc/v4l2-relayd.d/default.conf" "/etc/v4l2-relayd"; do
    if [ -f "$cfg" ]; then
        sed -i "s/WIDTH=[0-9]*/WIDTH=1920/" "$cfg"
        sed -i "s/HEIGHT=[0-9]*/HEIGHT=1080/" "$cfg"
        sed -i 's|VIDEOSRC=.*|VIDEOSRC="icamerasrc buffer-count=7 sharpness=30 saturation=10 wdr-level=120 ! videoflip video-direction=horiz"|' "$cfg"
        echo -e " ${GREEN}✔ Updated $cfg to 1920x1080 + ISP Sharpness/WDR tuning & un-mirroring${RESET}"
    fi
done

# 3. Install OEM Camera Tuning Calibration Binaries & Fix libcamhal Profiles
echo -e "\n${BOLD}[3/6] Installing OEM Camera Calibration Data (KBFC645) & Profiles...${RESET}"
if [ -n "$SRC_DIR" ] && [ -d "$SRC_DIR" ]; then
    for dir in /etc/camera/ipu6 /etc/camera/ipu6ep /etc/camera/ipu6epmtl; do
        if [ -d "$dir" ]; then
            cp -vf "$SRC_DIR/OV02C10_KBFC645_ADL.aiqb" "$dir/"
            cp -vf "$SRC_DIR/OV02C10_KBFC645_ADL.cpf" "$dir/"
        fi
    done

    for dir in /etc/camera/ipu6/gcss /etc/camera/ipu6ep/gcss /etc/camera/ipu6epmtl/gcss; do
        if [ -d "$dir" ]; then
            cp -vf "$SRC_DIR/graph_settings_OV02C10_KBFC645_ADL.xml" "$dir/"
        fi
    done

    for sensor_xml in /etc/camera/ipu6/sensors/ov02c10-uf.xml /etc/camera/ipu6ep/sensors/ov02c10-uf.xml /etc/camera/ipu6epmtl/sensors/ov02c10-uf.xml; do
        if [ -f "$sensor_xml" ]; then
            sed -i "s/OV02C10_[A-Z0-9]*_ADL/OV02C10_KBFC645_ADL/g" "$sensor_xml"
            sed -i 's/supportedAeExposureTimeRange value="AUTO,10,1000000"/supportedAeExposureTimeRange value="AUTO,100,1000000"/' "$sensor_xml"
            sed -i 's/supportedAeGainRange value="AUTO,0,60"/supportedAeGainRange value="AUTO,1,60"/' "$sensor_xml"
            echo -e " ${GREEN}✔ Updated $sensor_xml (KBFC645 profile & AE Exposure/Gain range fix)${RESET}"
        fi
    done

    # Register ov02c10-uf-0 on CSI Port 0 in libcamhal_profile.xml
    for profile in /etc/camera/ipu6/libcamhal_profile.xml /etc/camera/ipu6ep/libcamhal_profile.xml /etc/camera/ipu6epmtl/libcamhal_profile.xml; do
        if [ -f "$profile" ] && ! grep -q "ov02c10-uf-0" "$profile"; then
            sed -i "s/ov02c10-uf-1/ov02c10-uf-0,ov02c10-uf-1/g" "$profile"
            echo -e " ${GREEN}✔ Added ov02c10-uf-0 (CSI Port 0) to $profile${RESET}"
        fi
    done

    # Create sensor definition symlink for ov02c10-uf-0.xml
    for sdir in /etc/camera/ipu6/sensors /etc/camera/ipu6ep/sensors /etc/camera/ipu6epmtl/sensors; do
        if [ -d "$sdir" ] && [ -f "$sdir/ov02c10-uf.xml" ]; then
            ln -sf ov02c10-uf.xml "$sdir/ov02c10-uf-0.xml"
            echo -e " ${GREEN}✔ Linked $sdir/ov02c10-uf-0.xml -> ov02c10-uf.xml${RESET}"
        fi
    done
else
    echo -e " ${RED}✘ OEM calibration directory not found in $LOCAL_OEM_DIR.${RESET}"
    exit 1
fi

# 4. Configure User WirePlumber PipeWire Camera Routing Rule
TARGET_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$TARGET_USER")
WP_LUA_DIR="$USER_HOME/.config/wireplumber/main.lua.d"

echo -e "\n${BOLD}[4/6] Configuring WirePlumber PipeWire Routing Rules...${RESET}"
mkdir -p "$WP_LUA_DIR"
cat << "LUAEOF" > "$WP_LUA_DIR/51-disable-ipu6-raw.lua"
rule = {
  matches = {
    {
      { "device.bus-path", "matches", "pci-0000:00:05.0" },
    },
  },
  apply_properties = {
    ["device.disabled"] = true,
  },
}
table.insert(v4l2_monitor.rules, rule)
LUAEOF
chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME/.config/wireplumber"
echo -e " ${GREEN}✔ WirePlumber PipeWire routing rule created in $WP_LUA_DIR/51-disable-ipu6-raw.lua${RESET}"

# 5. Reload Kernel Modules & Restart Services (Stop relay daemon FIRST so v4l2loopback can un-bind)
echo -e "\n${BOLD}[5/6] Reloading kernel modules and restarting services...${RESET}"
systemctl stop v4l2-relayd@default.service || true
pkill -9 -f "v4l2src" || true
pkill -9 -f "v4l2-relayd" || true
sleep 1

if lsmod | grep -q "v4l2loopback"; then
    modprobe -r v4l2loopback || true
fi
modprobe v4l2loopback

systemctl start v4l2-relayd@default.service

if [ -n "$SUDO_USER" ]; then
    sudo -u "$SUDO_USER" DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$SUDO_USER")/bus systemctl --user restart wireplumber || true
fi

# 6. Verification Test
echo -e "\n${BOLD}[6/6] Verifying Camera Stream Output...${RESET}"
sleep 2
if [ -c "/dev/video0" ]; then
    echo -e " Active V4L2 Device Format:"
    v4l2-ctl -d /dev/video0 --get-fmt-video | sed "s/^/   /"
    
    echo -e " Capturing test frame to /tmp/samsung_camera_test.jpg..."
    if timeout --signal=2 5s gst-launch-1.0 -q v4l2src device=/dev/video0 num-buffers=10 ! videoconvert ! jpegenc ! filesink location=/tmp/samsung_camera_test.jpg; then
        echo -e " ${GREEN}✔ Test frame captured successfully to /tmp/samsung_camera_test.jpg!${RESET}"
    fi
fi

echo -e "\n${BOLD}${CYAN}================================================================${RESET}"
echo -e "${BOLD}${CYAN} Setup Complete! Samsung Galaxy Book3 Ultra Webcam 1080p Ready. ${RESET}"
echo -e "${BOLD}${CYAN}================================================================${RESET}\n"
