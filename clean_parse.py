import json
import json5

with open("all-optionsv6.json", "r") as f:
    data = json5.load(f)   # handles // and /* */ comments

with open("cleanv6.json", "w") as f:
    json.dump(data, f, indent=2)

print("cleanv6.json written successfully")
