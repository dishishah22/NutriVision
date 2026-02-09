with open("backend_debug.log", "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()
    for i, line in enumerate(lines):
        if "meta-llama/llama-4-scout" in line:
            print("FOUND AT LINE", i)
            for j in range(i, min(i+10, len(lines))):
                print(lines[j].strip())
