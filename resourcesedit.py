#!/usr/bin/env python3
import os

# Path to your categories
CATEGORIES_DIR = "categories"
OUTPUT_FILE = "resources.txt"

# Gather all apps from category files
apps = set()
for filename in os.listdir(CATEGORIES_DIR):
    if filename.endswith(".txt"):
        with open(os.path.join(CATEGORIES_DIR, filename)) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    apps.add(line)

apps = sorted(apps)

# Prepare resources dictionary
resources = {}

print("Manual resource installer setup")
print("You will enter installation methods for macOS and Arch for each app.")
print("Leave blank or type 'N/A' to skip installation on that OS.\n")

for app in apps:
    print(f"App: {app}")
    macos_method = input("  macOS install command: ").strip()
    if not macos_method:
        macos_method = "N/A"
    arch_method = input("  Arch install command: ").strip()
    if not arch_method:
        arch_method = "N/A"
    resources[app] = (macos_method, arch_method)
    print()  # spacing

# Write resources.txt
with open(OUTPUT_FILE, "w") as f:
    for app, (macos, arch) in resources.items():
        f.write(f"{app}:{macos}:{arch}\n")

print(f"\nAll done! Resource mapping saved to {OUTPUT_FILE}")

