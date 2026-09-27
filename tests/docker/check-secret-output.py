"""Check installer output without displaying any credential values."""
# Test harness: arguments = disposable configuration, followed by log files to check.
# Search only for literal values, not their encoded or transformed representations.
from pathlib import Path
import sys

config = Path(sys.argv[1])
logs = [Path(name) for name in sys.argv[2:]]
for line in config.read_text().splitlines():
    if not line or line.startswith("#"):
        continue
    key, value = line.split("=", 1)
    # Update these patterns when new families of secrets are added to the template.
    if any(part in key for part in ("PASSWORD", "SECRET_KEY", "AES_256_KEY")) and value:
        for log in logs:
            if value in log.read_text():
                # The diagnostic names the key and file without repeating the discovered secret.
                raise SystemExit(f"Credential {key} was found in {log.name}")
print("PASS: no configuration secret appears in installer output.")
