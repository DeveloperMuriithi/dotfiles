import re

with open("resources.txt", "r") as f:
    lines = f.readlines()

cleaned = []
for line in lines:
    app, mac, linux = line.strip().split(":", 2)

    
    # Clean Linux commands
if linux not in ["N/A", ""]:
    # Remove sudo
    linux = re.sub(r"^sudo\s+", "", linux)

    # ─── PACMAN / YAY ─────────────────────
    m = re.match(r"(pacman|yay)\s+-S\S*\s*([^\s&&]*)", linux)
    if m:
        pkg = m.group(2)
        linux = f"{m.group(1)} -S {pkg}"

    # ─── APT (Ubuntu/Debian) ──────────────
    else:
        m = re.match(r"apt\s+install\s+([^\s&&]+)", linux)
        if m:
            pkg = m.group(1)
            linux = f"apt install {pkg}"

        else:
            # fallback for pacman/yay weird cases
            if linux.startswith(("pacman", "yay")):
                parts = linux.split()
                if len(parts) >= 3:
                    linux = f"{parts[0]} -S {parts[2]}"

    
    cleaned.append(f"{app}:{mac}:{linux}")

with open("resources.txt", "w") as f:
    f.write("\n".join(cleaned))

