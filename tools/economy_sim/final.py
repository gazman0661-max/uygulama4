"""Kodla hizali ekonomi raporu:  python3 final.py"""
from sim import *

def show(name, P, days=700):
    r = run(P, days); d = r['done']
    print(f"{name:<22} sehir:{str(d['town']):>5} cizgi+slot:{str(d['lines']):>5} duvar:{str(r['stall_day']):>5} | "
          f"bolum/gun {r['ch_day']:>4.1f}  bolum-coin/gun {r['chcoin_day']:>6.0f}  toplam-coin/gun {r['income_day']:>6.0f}  bedava-elmas/gun {r['gems_day']:>4.1f}")
    print('   ' + ' '.join(f"g{k}:ch{v['ch']}/T{v['town']}/L{v['lines']}/b{v['builders']}" for k, v in r['hist'].items() if k in (7, 30, 90, 180, 360)))
    pk = [0, 30, 90, 180, 360]; H = r['hist']; row = []
    for a, b in zip(pk, pk[1:]):
        ga = H[a]['gems_cum'] if a else 0; ia = H[a]['income_cum'] if a else 0
        row.append(f"g{a+1}-{b}: {(H[b]['gems_cum']-ga)/(b-a):.0f} elmas, {(H[b]['income_cum']-ia)/(b-a)/1000:.1f}k coin /gun")
    print('   ' + ' | '.join(row))

print('== Oyuncu profilleri (varsayilan: israf %30 sadece merge coin, dolu masa acik) ==')
for nm, m, s in (('Gundelik 20dk', 20, 1), ('HEDEF 45dk', 45, 2), ('Yogun 120dk', 120, 3)):
    show(nm, dict(minutes=m, sessions=s))
print('\n== Duyarlilik (45dk) ==')
show('israf %0 (iyimser)', dict(waste=0.0))
show('israf %60', dict(waste=0.6))
show('verim 0.55 (kotu oyuncu)', dict(eff=0.55))
show('atis 1.8s', dict(interval=1.8))
show('reklam/cark yok', dict(wheel=0, ad_gems=0))
print('\nmaliyet toplam: sehir', int(sum(BASE_COST) * 8.25), 'cizgi', 2 * sum(LINE), 'slot', sum(SLOT))

print('\n== Dogrulama: ham bolum coin (israf 0, prefill kapali, carpan dahil) - elle hesapla ayni cikmali ==')
P0 = dict(DEFAULTS, waste=0.0, prefill=False, fixed=False)  # eski tier-bazli model (elle hesapla ayni cikmali)
for ch in (2, 6, 12, 24, 48, 101, 201, 401):
    g, cc, mn, t = chapter(ch, P0)
    print(f"  ch{ch:>4} {kind(ch):<6} hedef {g:>2}  coin {cc:>6.0f}  ~{mn:>4.1f} dk")

print('\n== v125: kademeli sabit bolum coin (kod: ChapterConfig.chapterCoinsFor) / eski tier-bazli sim - denge kontrolu ==')
Pd = dict(DEFAULTS, fixed=False)
for ch in (6, 12, 24, 50, 100, 200, 400, 800):
    n = ch
    while kind(n) != 'normal': n += 1
    g, cc, mn, t = chapter(n, Pd)
    fx = fixed_coins(n)
    print(f"  ch{n:>4} eski-sim {cc:>6.0f}  sabit {fx:>5}  fark {100*(fx-cc)/cc:>+4.0f}%")
