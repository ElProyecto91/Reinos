# Resume un torneo de tools/civ_arena.sh: porcentaje de victorias por civilización, matriz de enfrentamientos y duración.
# Uso: python3 tools/civ_arena_report.py /tmp/arena.txt
import re,sys,collections
f=sys.argv[1]
rows=[]
for l in open(f):
    if not l.startswith("RESULT"): continue
    m=re.search(r"over=(\w+) winner=(-?\d+) t=(\d+)s",l)
    civs=re.findall(r"P(\d) civ=(\w*) abil=(\d+)",l)
    kills=re.findall(r"P(\d) [VX] pop (\d+) vill (\d+) mil (\d+) kills (\d+)",l)
    if not m or len(civs)<2: continue
    over=m.group(1)=="true"; w=int(m.group(2)); t=int(m.group(3))
    c=[civs[0][1] or "none",civs[1][1] or "none"]
    ab=[int(civs[0][2]),int(civs[1][2])]
    k=[int(kills[0][4]),int(kills[1][4])]
    if not over:
        # sin ganador: decide por bajas (empate si cercano)
        w = 0 if k[0]>k[1]*1.5 else (1 if k[1]>k[0]*1.5 else -1)
    rows.append((c,w,t,ab,over))
# estadísticas por civ
st=collections.defaultdict(lambda:[0,0,0,0.0,0,0])  # win loss draw dur n abil
vs=collections.defaultdict(lambda:[0,0])
for c,w,t,ab,over in rows:
    for i in (0,1):
        s=st[c[i]]
        s[4]+=1; s[3]+=t; s[5]+=ab[i]
        if w==i: s[0]+=1
        elif w==1-i: s[1]+=1
        else: s[2]+=1
    if w in (0,1):
        vs[(c[w],c[1-w])][0]+=1
print("partidas:",len(rows), " sin ganador:",sum(1 for r in rows if not r[4]))
print("%-12s %4s %4s %4s  %6s  %6s  %6s"%("civ","G","P","E","win%","dur(s)","abil/partida"))
for civ,s in sorted(st.items(), key=lambda x:-(x[1][0]+0.5*x[1][2])/max(1,x[1][4])):
    wr=(s[0]+0.5*s[2])/max(1,s[4])*100
    print("%-12s %4d %4d %4d  %5.1f%%  %6.0f  %5.1f"%(civ,s[0],s[1],s[2],wr,s[3]/max(1,s[4]),s[5]/max(1,s[4])))
# solo entre civilizaciones (sin la base «none»)
st2=collections.defaultdict(lambda:[0,0,0,0])
for c,w,t,ab,over in rows:
    if "none" in c: continue
    for i in (0,1):
        s2=st2[c[i]]; s2[3]+=1
        if w==i: s2[0]+=1
        elif w==1-i: s2[1]+=1
        else: s2[2]+=1
print("\nSOLO CIV vs CIV (sin base):")
for civ,s2 in sorted(st2.items(), key=lambda x:-(x[1][0]+0.5*x[1][2])/max(1,x[1][3])):
    n=s2[3]; wr=(s2[0]+0.5*s2[2])/max(1,n)
    se=(wr*(1-wr)/max(1,n))**0.5
    print("%-12s %3d partidas  win %5.1f%% ±%.1f   (G%d P%d E%d)"%(civ,n,wr*100,se*100,s2[0],s2[1],s2[2]))
# lado: ¿gana más el jugador 0?
p0=sum(1 for r in rows if r[1]==0); p1=sum(1 for r in rows if r[1]==1)
print("victorias lado P0:",p0," lado P1:",p1)
# matriz
names=sorted(st.keys())
print("\nmatriz (fila gana a columna: victorias-derrotas)")
print("%-12s"%""+"".join("%6s"%n[:5] for n in names))
for a in names:
    line="%-12s"%a
    for b in names:
        if a==b: line+="%6s"%"."; continue
        w=vs[(a,b)][0]; l=vs[(b,a)][0]
        line+="%6s"%("%d-%d"%(w,l))
    print(line)
