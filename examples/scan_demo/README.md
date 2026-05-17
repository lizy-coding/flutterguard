# Scan Demo

A deliberately imperfect project to demonstrate `flutterguard scan`.

```bash
# From the repo root, run scan with low thresholds to trigger issues
./flutterguard scan -p examples/scan_demo

# With verbose output
./flutterguard scan -p examples/scan_demo --verbose

# JSON output
./flutterguard scan -p examples/scan_demo --format json
```

The `flutterguard.yaml` in this directory uses low thresholds (maxLines: 80/30/20) to demonstrate issue detection even in small projects.
