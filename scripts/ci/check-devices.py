#!/usr/bin/env python3
"""Keep the Connect IQ manifest and build matrix in agreement."""

from pathlib import Path
import json
import os
import sys
import xml.etree.ElementTree as ET


root = Path(__file__).resolve().parents[2]
listed = [line.strip() for line in (root / "supported-devices.txt").read_text().splitlines()
          if line.strip() and not line.startswith("#")]
manifest = ET.parse(root / "manifest.xml").getroot()
namespace = {"iq": "http://www.garmin.com/xml/connectiq"}
products = [node.attrib["id"] for node in manifest.findall(".//iq:product", namespace)]

if not listed or len(listed) != len(set(listed)) or listed != sorted(listed):
    sys.exit("supported-devices.txt must contain unique, sorted device IDs")
if listed != products:
    sys.exit("manifest.xml products differ from supported-devices.txt")

device_home = Path(os.environ.get("CIQ_DEVICE_HOME", Path.home() / ".Garmin/ConnectIQ/Devices"))
for device in listed:
    path = device_home / device / "compiler.json"
    if not path.is_file():
        sys.exit(f"Missing SDK device definition: {device}")
    data = json.loads(path.read_text())
    app_types = {item["type"] for item in data.get("appTypes", [])}
    versions = [tuple(map(int, part["connectIQVersion"].split(".")))
                for part in data.get("partNumbers", [])]
    if (not data.get("deviceFamily", "").startswith("round-")
            or not {"watchApp", "background", "glance"} <= app_types
            or not versions or min(versions) < (5, 1, 0)):
        sys.exit(f"Device does not meet the compatibility tier: {device}")
print(f"Device matrix matches manifest: {len(listed)} products")
