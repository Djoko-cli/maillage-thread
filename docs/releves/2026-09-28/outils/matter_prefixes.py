import subprocess, re, collections
def dnssd(args, secondes):
    # pseudo-terminal (script) : dns-sd ecrit ligne a ligne ; coupe apres le delai
    p = subprocess.Popen(["script", "-q", "/dev/null", "dns-sd"] + args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    try: out, _ = p.communicate(timeout=secondes)
    except subprocess.TimeoutExpired:
        p.kill(); out, _ = p.communicate()
    return out
instances = sorted(set(re.findall(r"Add\s+\d+\s+\d+\s+local\.\s+_matter\._tcp\.\s+(\S+)", dnssd(["-B", "_matter._tcp", "local."], 4))))
print(len(instances), "instances _matter._tcp")
hotes = {}
for inst in instances:
    m = re.search(r"can be reached at (\S+?)\.?:(\d+)", dnssd(["-L", inst, "_matter._tcp", "local."], 2))
    if m: hotes.setdefault(m.group(1), []).append(inst)
parts = collections.defaultdict(list)
for hote, insts in sorted(hotes.items()):
    adrs = set(a.lower() for a in re.findall(r"\s([0-9A-Fa-f:]+:[0-9A-Fa-f]+)(?:%\S+)?\s+\d+\s*$", dnssd(["-G", "v6", hote], 2), re.M))
    omr = sorted(a for a in adrs if not a.startswith("fe80"))
    cle = "Aqara (fd0d)" if any(a.startswith("fd0d:") for a in omr) else "Apple (fd2d)" if any(a.startswith("fd2d:") for a in omr) else "autre / aucune"
    parts[cle].append((hote, len(insts), omr[:3]))
for cle, l in parts.items():
    print(f"== {cle} : {len(l)} appareil(s)")
    for hote, n, omr in l: print(f"   {hote} ({n} fabrique(s)) {' '.join(omr)}")
