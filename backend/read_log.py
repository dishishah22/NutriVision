with open("backend_debug.log", "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()
    for line in lines[-30:]:
        print(line.strip())
