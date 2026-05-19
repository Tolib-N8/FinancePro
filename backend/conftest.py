import sys
from pathlib import Path

# Ensure the backend root (containing the `app` package) is importable
# regardless of pytest's invocation directory.
sys.path.insert(0, str(Path(__file__).parent))
