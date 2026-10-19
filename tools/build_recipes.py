"""Build Data.lua: every profession recipe (grouped like AtlasLoot), with reagents,
items made per craft, item slot/type, quality, item names and vendor prices.

Usage: python build_recipes.py <AtlasLoot_Crafting/crafting.lua> ../Data.lua
Run extract_game_data.py first.
"""
import re, sys, pickle
items, vendor, spells = pickle.load(open('build/db.pkl','rb'))
used=set()
SLOTS = {1:'Head',2:'Neck',3:'Shoulder',4:'Shirt',5:'Chest',20:'Chest',6:'Waist',7:'Legs',8:'Feet',9:'Wrist',10:'Hands',
 11:'Finger',12:'Trinket',16:'Back',13:'One-Hand',21:'Main Hand',17:'Two-Hand',22:'Off Hand',23:'Held In Off-hand',14:'Shield',
 15:'Ranged',25:'Ranged',26:'Ranged',28:'Relic',18:'Bag',19:'Tabard',24:'Ammo',27:'Quiver'}
CLS = {(0,1):'Potions',(0,2):'Elixirs',(0,3):'Flasks',(0,4):'Scrolls',(0,5):'Food & Drink',(0,6):'Item Enhancements',(0,7):'Bandages',
 (3,0):'Red Gems',(3,1):'Blue Gems',(3,2):'Yellow Gems',(3,3):'Purple Gems',(3,4):'Green Gems',(3,5):'Orange Gems',(3,6):'Meta Gems',(3,7):'Simple Gems',(3,8):'Prismatic Gems',
 (7,1):'Parts',(7,2):'Explosives',(7,3):'Devices',(7,4):'Jewelcrafting',(7,5):'Cloth',(7,6):'Leather',(7,7):'Metal & Stone',(7,10):'Elemental',(7,12):'Enchanting',(7,14):'Armor Enhancements',(7,15):'Weapon Enhancements',
 (16,0):'Glyphs',(6,2):'Arrows',(6,3):'Bullets'}
CLSNAME = {0:'Consumables',1:'Bags',2:'Weapons',3:'Gems',4:'Armor',6:'Ammo',7:'Trade Goods',11:'Quivers',12:'Quest',15:'Miscellaneous',16:'Glyphs'}
def group(item, name):
    if not item or item not in items: return 'Enchants' if name.startswith('Enchant') else 'Other'
    _,_,_,cl,sc,inv,_ = items[item]
    if inv in SLOTS: return SLOTS[inv]
    return CLS.get((cl,sc)) or CLSNAME.get(cl, 'Other')
src = open(sys.argv[1], encoding='utf-8', errors='replace').read()
end = src.index('--- Profession Sets ---')
body = src[:end]
tables = re.split(r'AtlasLoot_Data\["([^"]+)"\]\s*=\s*\{', body)
CATS = [
 ('AlchemyBattleElixir','Alchemy','Battle Elixirs'),('AlchemyGuardianElixir','Alchemy','Guardian Elixirs'),
 ('AlchemyPotion','Alchemy','Potions'),('AlchemyFlask','Alchemy','Flasks'),('AlchemyTransmute','Alchemy','Transmutes'),('AlchemyMisc','Alchemy','Miscellaneous'),
 ('SmithingArmorOld','Blacksmithing','Armor (Classic)'),('SmithingArmorBC','Blacksmithing','Armor (TBC)'),('SmithingArmorWrath','Blacksmithing','Armor (WotLK)'),
 ('SmithingWeaponOld','Blacksmithing','Weapons (Classic)'),('SmithingWeaponBC','Blacksmithing','Weapons (TBC)'),('SmithingWeaponWrath','Blacksmithing','Weapons (WotLK)'),
 ('SmithingEnhancement','Blacksmithing','Enhancements'),('SmithingMisc','Blacksmithing','Miscellaneous'),
 ('Armorsmith','Blacksmithing','Armorsmith'),('Weaponsmith','Blacksmithing','Weaponsmith'),('Axesmith','Blacksmithing','Axesmith'),('Hammersmith','Blacksmithing','Hammersmith'),('Swordsmith','Blacksmithing','Swordsmith'),
 ('Cooking','Cooking','Cooking'),
 ('EnchantingBoots','Enchanting','Boots'),('EnchantingBracer','Enchanting','Bracers'),('EnchantingChest','Enchanting','Chest'),('EnchantingCloak','Enchanting','Cloaks'),
 ('EnchantingGloves','Enchanting','Gloves'),('EnchantingRing','Enchanting','Rings'),('EnchantingShield','Enchanting','Shields'),('Enchanting2HWeapon','Enchanting','2H Weapons'),
 ('EnchantingWeapon','Enchanting','Weapons'),('EnchantingStaff','Enchanting','Staves'),('EnchantingMisc','Enchanting','Miscellaneous'),
 ('EngineeringAmmo','Engineering','Ammunition'),('EngineeringArmor','Engineering','Armor'),('EngineeringExplosives','Engineering','Explosives'),
 ('EngineeringItemEnhancements','Engineering','Enhancements'),('EngineeringMisc','Engineering','Miscellaneous'),('EngineeringReagents','Engineering','Reagents'),
 ('EngineeringWeapon','Engineering','Weapons'),('Gnomish','Engineering','Gnomish'),('Goblin','Engineering','Goblin'),
 ('FirstAid','First Aid','First Aid'),
 ('Inscription_OffHand','Inscription','Off-hands'),('Inscription_Reagents','Inscription','Inks & Parchment'),('Inscription_Scrolls','Inscription','Scrolls'),('Inscription_Misc','Inscription','Miscellaneous'),
 ('JewelRed','Jewelcrafting','Red Gems'),('JewelBlue','Jewelcrafting','Blue Gems'),('JewelYellow','Jewelcrafting','Yellow Gems'),('JewelGreen','Jewelcrafting','Green Gems'),
 ('JewelOrange','Jewelcrafting','Orange Gems'),('JewelPurple','Jewelcrafting','Purple Gems'),('JewelMeta','Jewelcrafting','Meta Gems'),('JewelPrismatic','Jewelcrafting','Prismatic Gems'),
 ('JewelDragonsEye',"Jewelcrafting","Dragon's Eye"),('JewelTrinket','Jewelcrafting','Trinkets'),('JewelRing','Jewelcrafting','Rings'),('JewelNeck','Jewelcrafting','Necks'),('JewelMisc','Jewelcrafting','Miscellaneous'),
 ('LeatherLeatherArmorOld','Leatherworking','Leather (Classic)'),('LeatherLeatherArmorBC','Leatherworking','Leather (TBC)'),('LeatherLeatherArmorWrath','Leatherworking','Leather (WotLK)'),
 ('LeatherMailArmorOld','Leatherworking','Mail (Classic)'),('LeatherMailArmorBC','Leatherworking','Mail (TBC)'),('LeatherMailArmorWrath','Leatherworking','Mail (WotLK)'),
 ('LeatherCloaks','Leatherworking','Cloaks'),('LeatherItemEnhancement','Leatherworking','Enhancements'),('LeatherQuiversPouches','Leatherworking','Quivers & Pouches'),
 ('LeatherDrumsBagsMisc','Leatherworking','Drums, Bags & Misc'),('LeatherLeather','Leatherworking','Leather'),('Dragonscale','Leatherworking','Dragonscale'),('Elemental','Leatherworking','Elemental'),('Tribal','Leatherworking','Tribal'),
 ('Mining','Mining','Smelting'),
 ('TailoringArmorOld','Tailoring','Armor (Classic)'),('TailoringArmorBC','Tailoring','Armor (TBC)'),('TailoringArmorWotLK','Tailoring','Armor (WotLK)'),
 ('TailoringBags','Tailoring','Bags'),('TailoringMisc','Tailoring','Miscellaneous'),('TailoringShirts','Tailoring','Shirts'),('Mooncloth','Tailoring','Mooncloth'),('Shadoweave','Tailoring','Shadoweave'),('Spellfire','Tailoring','Spellfire'),
]
def cat_for(key):
    m = re.match(r'Inscription_(\w+?)(Major|Minor)\d+$', key)
    if m: return ('Inscription', f'Glyphs: {m.group(1).replace("DeathKnight","Death Knight")} ({m.group(2)})')
    base = re.sub(r'\d+$','',key)
    for p,prof,c in CATS:
        if base == p: return (prof,c)
    return None
row = re.compile(r'\{\s*\d+\s*,\s*"s(\d+)"\s*,\s*"([^"]*)"\s*,\s*"=(q\d|ds)=([^"]*)"')
out=[]; seen=set(); unknown=set(); order=[]
for i in range(1,len(tables),2):
    key, tb = tables[i], tables[i+1]
    c = cat_for(key)
    rows = row.findall(tb)
    if not c:
        if rows: unknown.add(key)
        continue
    if c not in order: order.append(c)
    for spell,item,q,name in rows:
        if spell in seen: continue
        seen.add(spell)
        item = int(item) if item.isdigit() else 0
        out.append((c, int(spell), item, int(q[1]) if q.startswith('q') else 1, name.strip()))
print('unknown', unknown, file=sys.stderr)
print('recipes', len(out), 'noitem', sum(1 for o in out if not o[2]), file=sys.stderr)
profs=[]; 
for p,_ in order:
    if p not in profs: profs.append(p)
def lua(s): return '"' + s.replace('\\','\\\\').replace('"','\\"') + '"'
L=['-- Generated by tools/build_recipes.py from AtlasLoot_Crafting, the WotLK 3.3.5 Spell.dbc and the AzerothCore item database.','-- Do not edit by hand.','-- { spellID, createdItemID (0 = enchant), quality, name, itemsMadePerCraft, { reagentID, count, ... }, group }','','CraftOrBuy_Professions = {']
for p in profs:
    L.append(f'\t{{ name = {lua(p)}, categories = {{')
    for (pp,c) in order:
        if pp!=p: continue
        if not any(o[0]==(pp,c) for o in out): continue
        L.append(f'\t\t{{ name = {lua(c)}, recipes = {{')
        for o in out:
            if o[0]==(pp,c):
                reag, made, created = spells.get(o[1], ([], 1, 0))
                item = o[2] or created
                name = items[item][0] if item in items else o[4]
                if o[2] == 0: name = o[4]
                for rid, _ in reag: used.add(rid)
                if item: used.add(item)
                rs = ', '.join(f'{rid}, {c}' for rid, c in reag)
                mtxt = ('%g' % made)
                qual = items[item][6] if (o[2] and item in items) else o[3]
                L.append(f'\t\t\t{{ {o[1]}, {item if o[2] else 0}, {qual}, {lua(name)}, {mtxt}, {{ {rs} }}, {lua(group(item if o[2] else 0, name))} }},')
        L.append('\t\t} },')
    L.append('\t} },')
L.append('}')
L.append('')
L.append('-- Item names (reagents and crafted items), from the AzerothCore 3.3.5 database.')
L.append('CraftOrBuy_Items = {')
for i in sorted(used):
    if i in items: L.append(f'\t[{i}] = {lua(items[i][0])},')
L.append('}')
L.append('')
L.append('-- Vendor price per unit (copper) for reagents sold by NPCs in unlimited supply.')
L.append('CraftOrBuy_Vendor = {')
for i in sorted(used):
    if i in vendor and i in items and items[i][1] > 0:
        L.append(f'\t[{i}] = {items[i][1] / items[i][2]:g},')
L.append('}')
nore = sum(1 for o in out if not spells.get(o[1], ([],))[0])
print('recipes without reagents', nore, file=sys.stderr)
open(sys.argv[2],'w',encoding='utf-8').write('\n'.join(L)+'\n')
