"""Worlds Merge ekonomi simulatoru (v116: koda hizalandi; v125: kademeli sabit bolum coin'i, P[\'fixed\']=False eski modeli verir).

Kodla BIREBIR olanlar (lib/ altindaki sabitler):
  tier coin odulleri, siparis agirliklari (game_board._generateOrder), kural siparisi,
  boss/rahat bolum, hedef tavani 20, coin carpani (+%1/blok, en fazla x1.5), dolu masa
  (prefill), yukseltme/sehir/insaatci maliyetleri, insaat sureleri, yildiz sarti,
  onceki dunya sarti (5. seviye), pasif uretim (8 saat depo), Kasaba bonuslari
  (coin +%4/sv, gunluk +%10/sv, sans +%0.5/sv, atis -4ms/sv, elmas +1/3 sv),
  kasaba kilometre tasi odulleri, boss ilk gecis odulu, cark, gorevler.

VARSAYIM olanlar (oyuncu davranisi - cihazda olculmeli): interval, eff, waste, stars,
  sessions/minutes, wheel, ad_gems.

ESKI SIMDEN DUZELTMELER:
  1) 'waste' artik SADECE birlestirme coin'ine uygulanir (eski sim siparis odulunu de %30 sisiriyordu).
  2) Siparis agirliklari koddaki gibi (Lv7/Lv8, boss yumusak baslangic, kural siparisi lateT).
  3) Kasaba Lezzet Duragi (+%4/sv coin), Korsan (+%10/sv gunluk), Uzay (elmas), kilometre odulleri eklendi.
  4) Boss ilk gecis +3 elmas eklendi (eski sim sadece coin veriyordu).
  5) Hizli Atis / Sansli Baslangic yukseltmeleri artik hizi ve sansi gercekten degistirir.
  6) Onceki dunya sarti (5. seviye) varsayilan acik; dolu masa (prefill) varsayilan acik.
  7) Varsayilanlar (hedef tavani 20, carpan %1/x1.5) kodla ayni; eski cap40/mult x3 kalintilari kaldirildi.
"""
BCOST = [600, 1600]
R = [0, 1, 2, 3, 5, 8, 13, 21, 34]  # coinReward, tier 1..8
def M(L):  # L seviyeli topu birlestirerek yapmanin (israfsiz) merge coin'i
    return sum((2 ** (L - n)) * R[n] for n in range(2, L + 1))
U = lambda L: 2 ** (L - 1)
BASE_COST = [450, 1050, 2000, 7200, 12000, 19200, 60000, 84000, 114000, 156000]
STAR_REQ = [1, 2, 4, 6, 9, 12, 15, 18, 20, 22]
UP_MIN = [1, 10, 30, 90, 240, 480, 900, 1560, 2520, 4200]
PROD = [0, 3, 5, 7, 10, 13, 17, 21, 26, 31, 37]
LINE = [900, 1750, 3200, 10800, 18000, 28600, 43200, 90000, 122400, 165600, 223200, 398400, 528000, 696000, 912000]
SLOT = [1800, 5000]
DAILY = [50, 75, 100, 150, 200, 300, 500]
MILESTONES = [(3, 0, 3), (6, 500, 3), (10, 0, 8), (15, 1500, 5), (20, 0, 12), (25, 3000, 8), (30, 0, 20), (40, 6000, 25), (50, 0, 35), (60, 15000, 60)]
TAB0 = [5, 7, 9, 11, 13, 15, 17, 20]
GOAL_CAP = 20
DEFAULTS = dict(minutes=45, sessions=2, interval=1.2, eff=0.7, waste=0.3, stars=2.3, wheel=2, ad_gems=0.5,
                mult_rate=0.01, mult_cap=1.5, cost_scale=1.0, chain=5, prefill=True, perks=True,
                interval_floor=0.8)  # interval_floor: oyuncunun dokunma hizi siniri (sn/atis) - VARSAYIM

def kind(c):
    if c >= 5 and c % 10 == 0: return 'boss'
    if c >= 5 and c % 5 == 0: return 'easy'
    return 'normal'
def raw_goal(c):
    pos = ((c - 1) % 8) + 1; cyc = (c - 1) // 8
    if cyc == 0: return TAB0[pos - 1]
    return max(0, min(GOAL_CAP, 10 + pos * 5 + cyc * 20))
def goal(c):
    r = raw_goal(c); k = kind(c)
    return max(5, round(r * 0.7)) if k == 'easy' else max(5, round(r * 0.5)) if k == 'boss' else r
def diffT(c):
    t = min(1.0, (c - 1) / 40); return t * 0.4 if kind(c) == 'easy' else t
def bossT(c): return min(1.0, max(0.0, (c - 10) / 40))
def lateT(c): return min(1.0, max(0.0, (c - 41) / 60))
def coin_mult(P, c): return min(P['mult_cap'], 1 + P['mult_rate'] * ((c - 1) // 8))

def per_order(c):
    """Bir siparis icin beklenen (siparis_coin, merge_coin, birim_sayisi) - ham, carpansiz."""
    k = kind(c); t = diffT(c); bt = bossT(c)
    w7 = (8.0 if k == 'boss' else 2.0 + 2.0 * t) if (c >= 20 and k != 'easy') else 0.0
    w8 = 4.0 if (k == 'boss' and c >= 30) else 0.0
    if k == 'boss':
        w = [0, 0, 40 - 32 * bt, 35, 20 + 15 * bt, 5 + 17 * bt, w7, w8]
    else:
        w = [30 - 20 * t, 25 - 10 * t, 20 + 2 * t, 13 + 10 * t, 8 + 14 * t, 4 + 16 * t, w7, w8]
    tot = sum(w); eo = em = eu = 0.0
    for i, wi in enumerate(w):
        L = i + 1; p = wi / tot
        rew = R[L] * (2 if k == 'boss' else 1) * (1.25 if L == 7 else 1.5 if L == 8 else 1)
        eo += p * rew; em += p * M(L); eu += p * U(L)
    if k != 'boss' and c >= 6:
        pr = 0.12 + 0.18 * t + 0.10 * lateT(c)
        ro = rm = ru = 0.0
        for L in (3, 4, 5):
            ro += 1.25 * R[L] / 3; rm += M(L) / 3; ru += U(L) / 3
        eo = (1 - pr) * eo + pr * ro; em = (1 - pr) * em + pr * rm; eu = (1 - pr) * eu + pr * ru
    return eo, em, eu

def prefill_frac(c):
    if c < 3: return 0.0
    f = 0.5 * min(1.0, (c - 2) / 90)
    return f * 0.5 if kind(c) == 'easy' else f
def prefill_units(c):  # kapasite ~48 top x ortalama birim 2.36
    return round(prefill_frac(c) * 48) * 2.36

def fixed_coins(c):
    """v125: kodla BIREBIR (ChapterConfig.chapterCoinsFor): kademeli sabit bolum coin'i."""
    c = max(1, c)
    if c <= 5: v = 100 + (c - 1) * 50
    elif c <= 24: v = 400 + (c - 6) * (500 / 18)
    else: v = min(1400, 1000 + (c - 25) * 0.5)
    v = int(v / 10 + 0.5) * 10
    k = kind(c)
    return round(v * (1.5 if k == 'boss' else 0.7 if k == 'easy' else 1.0))

def chapter(c, P, luck=0, thr=0, perk_luck=0.0, perk_speed_ms=0.0):
    """-> (hedef, coin(ham, Kasaba bonusu HARIC), dakika, atis)"""
    g = goal(c); eo, em, eu = per_order(c); m = coin_mult(P, c)
    fixed = P.get('fixed', True)
    coins = fixed_coins(c) if fixed else g * (eo + em * (1 + P['waste'])) * m
    l2 = min(0.60, max(0.25, 0.25 + luck * 0.02 + perk_luck))
    spawn = (1 - l2) + 2 * l2
    throws = g * eu / (spawn * P['eff'])
    if P.get('prefill'):
        fu = prefill_units(c)
        throws = max(0.4 * throws, throws - fu / (spawn * P['eff']))
        if not fixed: coins = max(0.5 * coins, coins - fu * 1.5 * m)  # v125: sabit coin dolu masadan etkilenmez
    red = min(0.61, 0.03 * thr + perk_speed_ms / 1000.0)  # bekleme 700ms -> en az 90ms
    iv = max(min(P['interval'], P['interval_floor']), P['interval'] - red)
    minutes = throws * iv / 60 + 0.5
    return g, coins, minutes, throws

def run(P, days=540):
    P = dict(DEFAULTS, **P); CS = P['cost_scale']
    coins = 0.0; gems = 5.0; c = 1; energy = 5.0
    lv = [0] * 6; end = [0.0] * 6; builders = 1
    thr = luck = slot = 0; wstars = [0.0] * 6; hist = {}
    tot_minutes = 0.0; done = {'town': None, 'lines': None, 'all': None}
    wk = {'o': 0, 'm': 0, 'c': 0}; mo = {'o': 0, 'm': 0, 'c': 0}
    sess_hours = {1: [19], 2: [9, 20], 3: [8, 14, 21]}[P['sessions']]
    last_hour = None; sum_chcoin = 0.0; sum_income = 0.0; sum_gems = 0.0; chap_total = 0
    stalled = 0; stall_day = None; mil = 0
    for d in range(days):
        day_o = day_m = 0; day_c = 0.0; inc = 0.0; gin = 0.0
        for h in sess_hours:
            now = d * 24 + h
            for w in range(6):
                if end[w] > 0 and end[w] <= now: lv[w] += 1; end[w] = 0
            if last_hour is not None: energy = min(5.0, energy + (now - last_hour) * 6)
            last_hour = now
            budget = P['minutes'] / P['sessions']; limit = budget * 1.25
            pk = P['perks']
            cb = 1 + (0.04 * lv[0] if pk else 0)          # Lezzet Duragi: coin bonusu
            pl = 0.005 * lv[2] if pk else 0.0              # Buyu&Simya: sans
            ps = 4.0 * lv[4] if pk else 0.0                # Buz Sarayi: atis hizi
            gb = (lv[5] // 3) if pk else 0                 # Uzay Ist.: elmas / ilk gecis
            while budget > 0 and energy >= 1:
                g, cc, mins, thrs = chapter(c, P, luck, thr, pl, ps)
                if mins > limit:  # DUVAR: yeni bolum seansa sigmiyor -> eski bolumu tekrar oyna
                    cf = c - 1
                    while cf > 1 and (chapter(cf, P, luck, thr, pl, ps)[2] > limit or kind(cf) != 'normal'): cf -= 1
                    g, cc, mins, thrs = chapter(cf, P, luck, thr, pl, ps)
                    energy -= 1; energy = min(5.0, energy + mins / 10)
                    budget -= mins; tot_minutes += mins
                    coins += cc * cb; day_c += cc * cb; day_o += g; day_m += thrs * 0.6
                    stalled += 1; continue
                energy -= 1; energy = min(5.0, energy + mins / 10)
                budget -= mins; tot_minutes += mins
                coins += cc * cb; day_c += cc * cb; day_o += g; day_m += thrs * 0.6
                if c <= 3: coins += [150, 250, 400][c - 1]; inc += [150, 250, 400][c - 1]
                gn = (1 if c <= 20 else 0) + gb + (3 if c % 5 == 0 else 0)
                if kind(c) == 'boss': gn += 3; coins += 500; inc += 500
                gems += gn; gin += gn
                wstars[((c - 1) // 8) % 6] += P['stars']; c += 1; chap_total += 1
            gap = 24 / len(sess_hours)
            for w in range(6):
                rate = PROD[lv[w]] * (100 + 25 * w) // 100
                got = min(rate * gap, rate * 8); coins += got; inc += got
            while True:  # harca
                opts = []; busy = sum(1 for e in end if e > 0)
                for w in range(6):
                    if lv[w] < 10 and end[w] == 0 and busy < builders and c >= 8 * w + 1 and wstars[w] >= STAR_REQ[lv[w]] \
                            and (not P['chain'] or w == 0 or lv[w] > 0 or lv[w - 1] >= P['chain']):
                        cost = int(BASE_COST[lv[w]] * (100 + 15 * w) // 100 // 10 * 10 * CS)
                        if coins >= cost: opts.append((cost, 't', w))
                if thr < 15 and coins >= LINE[thr] * CS: opts.append((int(LINE[thr] * CS), 'thr', 0))
                if luck < 15 and coins >= LINE[luck] * CS: opts.append((int(LINE[luck] * CS), 'luck', 0))
                if slot < 2 and coins >= SLOT[slot] * CS: opts.append((int(SLOT[slot] * CS), 'slot', 0))
                if not opts: break
                cost, k, w = min(opts); coins -= cost
                if k == 't': end[w] = now + UP_MIN[lv[w]] * (100 + 10 * w) / 100 / 60
                elif k == 'thr': thr += 1
                elif k == 'luck': luck += 1
                else: slot += 1
            while mil < len(MILESTONES) and sum(lv) >= MILESTONES[mil][0]:
                coins += MILESTONES[mil][1]; inc += MILESTONES[mil][1]
                gems += MILESTONES[mil][2]; gin += MILESTONES[mil][2]; mil += 1
            if builders == 1 and gems >= BCOST[0]: gems -= BCOST[0]; builders = 2
            elif builders == 2 and gems >= BCOST[1]: gems -= BCOST[1]; builders = 3
        dc = DAILY[d % 7] * (1 + (0.10 * lv[3] if P['perks'] else 0)); coins += dc; inc += dc
        ok_o = day_o >= 40; ok_m = day_m >= 120; ok_c = day_c >= 900
        mc = 150 * ok_o + 120 * ok_m + 200 * ok_c; coins += mc; inc += mc
        for k, v in (('o', day_o), ('m', day_m), ('c', day_c)): wk[k] += v; mo[k] += v
        wc = P['wheel'] * 179; coins += wc; inc += wc
        wg = P['wheel'] * 0.54 + P['ad_gems'] * 6 + 5 / 7; gems += wg; gin += wg
        if (d + 1) % 7 == 0:
            x = 800 * (wk['o'] >= 200) + 600 * (wk['m'] >= 650) + 1000 * (wk['c'] >= 5500); coins += x; inc += x
            y = 5 * ((wk['o'] >= 200) + (wk['m'] >= 650) + (wk['c'] >= 5500)); gems += y; gin += y
            wk = {'o': 0, 'm': 0, 'c': 0}
        if (d + 1) % 30 == 0:
            x = 3000 * (mo['o'] >= 800) + 2200 * (mo['m'] >= 2600) + 4000 * (mo['c'] >= 22000); coins += x; inc += x
            y = 15 * ((mo['o'] >= 800) + (mo['m'] >= 2600) + (mo['c'] >= 22000)); gems += y; gin += y
            mo = {'o': 0, 'm': 0, 'c': 0}
        sum_chcoin += day_c; sum_income += day_c + inc; sum_gems += gin
        if stall_day is None and stalled > 0: stall_day = d + 1
        if done['town'] is None and sum(lv) >= 60: done['town'] = d + 1
        if done['lines'] is None and thr >= 15 and luck >= 15 and slot >= 2: done['lines'] = d + 1
        if done['all'] is None and done['town'] and done['lines']: done['all'] = d + 1
        if d + 1 in (7, 30, 90, 180, 360, 540): hist[d + 1] = dict(ch=c - 1, town=sum(lv), lines=thr + luck, coins=int(coins), gems=int(gems), builders=builders, gems_cum=sum_gems, income_cum=sum_income)
    return dict(done=done, hist=hist, min_day=tot_minutes / days, chcoin_day=sum_chcoin / days,
                income_day=sum_income / days, gems_day=sum_gems / days, ch_day=chap_total / days, stall_day=stall_day)
