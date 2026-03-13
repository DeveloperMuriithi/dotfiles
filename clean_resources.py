import re

with open("resources.txt", "r") as f:
    lines = f.readlines()

cleaned = []
for line in lines:
    app, mac, linux = line.strip().split(":")
    
    # Clean Linux commands
    if linux not in ["N/A", ""]:
        # Remove sudo
        linux = re.sub(r"^sudo\s+", "", linux)
        # Remove flags and extras after -S or -Syu
        m = re.match(r"(pacman|yay)\s+-S\S*\s*([^\s&&]*)", linux)
        if m:
            pkg = m.group(2)
            linux = f"{m.group(1)} -S {pkg}"
        else:
            # fallback: just remove everything after first -S
            linux = re.sub(r"(pacman|yay)\s+-S\S*.*", lambda x: x.group(0).split()[0]+" -S "+x.group(0).split()[2], linux)
    
    cleaned.append(f"{app}:{mac}:{linux}")

with open("resources.txt", "w") as f:
    f.write("\n".join(cleaned))

