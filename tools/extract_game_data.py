"""Read item names, qualities, slots, vendor items and recipe reagents from the
3.3.5 game data into build/db.pkl, used by build_recipes.py.

Needs in build/: item_template.sql and npc_vendor.sql (AzerothCore world database)
and dbc/Spell.dbc (3.3.5a client).
"""
import sys, struct, re, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sqlparse import columns, rows
it = open('build/item_template.sql', encoding='utf-8').read()
cols = columns(it); ie, iname, ibp, ibc = cols.index('entry'), cols.index('name'), cols.index('BuyPrice'), cols.index('BuyCount')
icl, isc, iinv, iq = cols.index('class'), cols.index('subclass'), cols.index('InventoryType'), cols.index('Quality')
items = {}
for v in rows(it):
    items[int(v[ie])] = (v[iname].strip(), int(v[ibp]), max(int(v[ibc]),1), int(v[icl]), int(v[isc]), int(v[iinv]), int(v[iq]))
print('items', len(items), file=sys.stderr)
nv = open('build/npc_vendor.sql', encoding='utf-8').read()
vc = columns(nv); vi, vm, vx = vc.index('item'), vc.index('maxcount'), vc.index('ExtendedCost')
vendor = set()
for v in rows(nv):
    if int(v[vm]) == 0 and int(v[vx]) == 0: vendor.add(abs(int(v[vi])))
print('vendor items', len(vendor), file=sys.stderr)
f = open('build/dbc/Spell.dbc','rb').read()
_, rec, fields, size, _ = struct.unpack('<4s4I', f[:20])
spells = {}
def sgn(x): return x - 2**32 if x >= 2**31 else x
for i in range(rec):
    r = struct.unpack_from('<%dI' % fields, f, 20 + i*size)
    reag = [(r[52+k], r[60+k]) for k in range(8) if r[52+k] and r[60+k]]
    made = 1; created = 0
    for e in range(3):
        if r[71+e] == 24:  # SPELL_EFFECT_CREATE_ITEM
            bp, die = sgn(r[80+e]), sgn(r[74+e])
            made = bp + (1 + die) / 2 if die > 1 else bp + 1
            created = r[107+e]; break
    spells[r[0]] = (reag, made, created)
import pickle; pickle.dump((items, vendor, spells), open('build/db.pkl','wb'))
print('spells', len(spells), file=sys.stderr)
