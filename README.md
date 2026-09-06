# Samsung Galaxy Book3 Ultra Webcam (Intel IPU6 + OV02C10) Linux Driver & 1080p Setup

This repository provides an automated installation setup and color-tuning configuration for the **Samsung Galaxy Book3 Ultra** (and compatible Galaxy Book3 laptops) running Linux (Ubuntu/Debian, Fedora, Arch, etc.).

It solves the common issues with Intel 13th Gen IPU6 MIPI CSI-2 cameras on Linux:
- ❌ Black/dark screen output (traced to missing OEM `KBFC645` camera calibration data).
- ❌ Low resolution limit (720p cap).
- ❌ PipeWire/WirePlumber selecting raw Bayer nodes instead of the processed V4L2 virtual camera.
- ❌ `libcamhal` falling back to generic `AR0234` profile due to unmapped CSI Port 0 (`ov02c10-uf-0`).

---

## 📷 Hardware Specifications
- **Laptop Model**: Samsung Galaxy Book3 Ultra (NP960XFH / 13th Gen Intel Core i7/i9)
- **Host Interface**: Intel IPU6 (PCI ID `8086:a75d`)
- **Camera Sensor**: OmniVision OV02C10 (1080p FHD MIPI CSI-2, Module `KBFC645`)
- **Linux Architecture**: `intel_ipu6` kernel drivers -> `libcamhal` / `icamerasrc` -> `v4l2-relayd` -> `/dev/video0` (`v4l2loopback`) -> PipeWire / WebRTC / Apps.

---

## 🚀 Quick Start

Run the automated setup script with sudo privileges:

```bash
sudo ./setup_samsung_galaxybook3_webcam.sh
```

---

## 📁 Repository Structure

```
samsung/
├── setup_samsung_galaxybook3_webcam.sh  # Master automated setup & calibration script
├── oem_camera_files/                    # Extracted Windows OEM calibration files
│   ├── OV02C10_KBFC645_ADL.aiqb         # 3A Auto-Exposure / White Balance tuning binary
│   ├── OV02C10_KBFC645_ADL.cpf          # Camera parameter profile
│   ├── graph_settings_OV02C10_KBFC645_ADL.xml # IPU6 PSys graph pipeline configuration
│   └── ...
└── README.md                            # This documentation file
```

---

## ⚙️ What the Setup Script Configures

1. **v4l2loopback 1080p Resolution Cap**:
   Updates `/etc/modprobe.d/v4l2loopback.conf` to allow `max_width=1920` and `max_height=1080`.

2. **v4l2-relayd Daemon Configuration**:
   Sets `/etc/default/v4l2-relayd` parameters to `WIDTH=1920`, `HEIGHT=1080`, `FORMAT=NV12`, `FRAMERATE=30/1`, and `VIDEOSRC="icamerasrc buffer-count=7 sharpness=30 saturation=10 wdr-level=120 ! videoflip video-direction=horiz"` to enhance image sharpness, color saturation, wide dynamic range (WDR), and horizontal un-mirroring.

3. **OEM Calibration & Color Tuning Installation**:
   Copies `OV02C10_KBFC645_ADL.aiqb`, `.cpf`, and graph XML settings into `/etc/camera/ipu6/`, `/etc/camera/ipu6ep/`, and `/etc/camera/ipu6epmtl/`. Updates sensor definitions to link the `KBFC645` tuning file.

4. **libcamhal CSI Port 0 Profile Fix**:
   Registers `ov02c10-uf-0` on CSI Port 0 (`Intel IPU6 CSI2 0`) inside `libcamhal_profile.xml` to prevent `libcamhal` from falling back to generic `AR0234` profiles.

5. **PipeWire / WirePlumber Routing Rule**:
   Creates `~/.config/wireplumber/main.lua.d/51-disable-ipu6-raw.lua` to disable the 32 raw IPU6 hardware nodes (`/dev/video1`..`/dev/video32`), ensuring modern Linux desktop environments pick **Intel MIPI Camera** (`/dev/video0`) as the single active camera.

---

## 🧪 Verification & Usage

### 1. Test Frame Capture
After running the script, verify that a test frame was captured cleanly:
```bash
ls -la /tmp/samsung_camera_test.jpg
```

### 2. Live Video Playback
Open any camera application or WebRTC browser session:
- **GNOME Camera** (`snapshot`)
- **Cheese**
- **OBS Studio** (V4L2 Video Capture Device -> `/dev/video0`)
- **Web Browsers**: Google Chrome, Mozilla Firefox, Brave (Google Meet, Zoom, WebRTC)

---

## 🛠️ Service Management

To check the camera daemon status or restart services manually:

```bash
# Check service status
systemctl status v4l2-relayd@default.service

# Check system logs for camera HAL errors
journalctl -u v4l2-relayd@default.service -n 50 --no-pager

# Restart service
sudo systemctl restart v4l2-relayd@default.service
```
