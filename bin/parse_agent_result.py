#!/usr/bin/env python3
import json, re, sys, pathlib

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="replace")

keys = ["SUMMARY", "ROOT_CAUSE", "CHANGED_FILES", "COMMANDS_RUN", "TEST_RESULT", "RISKS", "NEXT_STEP"]
result = {k.lower(): "" for k in keys}

pattern = re.compile(r'^(SUMMARY|ROOT_CAUSE|CHANGED_FILES|COMMANDS_RUN|TEST_RESULT|RISKS|NEXT_STEP):\s*$', re.M)
matches = list(pattern.finditer(text))

for i, m in enumerate(matches):
    key = m.group(1).lower()
    start = m.end()
    end = matches[i+1].start() if i + 1 < len(matches) else len(text)
    result[key] = text[start:end].strip()

print(json.dumps(result, ensure_ascii=False, indent=2))
