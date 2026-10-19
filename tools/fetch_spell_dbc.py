"""Download single files (e.g. Spell.dbc) out of a large remote zip using HTTP range requests.

Usage: python fetch_spell_dbc.py <zip url> Spell.dbc
Files are written to build/.
"""
import io, zipfile, requests, sys
url = sys.argv[1]; wanted = sys.argv[2:]
s = requests.Session()
r = s.head(url, allow_redirects=True); real = r.url; size = int(r.headers['Content-Length'])
class RF(io.RawIOBase):
    def __init__(self): self.pos = 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else (self.pos + off if whence == 1 else size + off); return self.pos
    def read(self, n=-1):
        if n < 0: n = size - self.pos
        if n == 0 or self.pos >= size: return b''
        end = min(self.pos + n, size) - 1
        d = s.get(real, headers={'Range': f'bytes={self.pos}-{end}'}).content
        self.pos += len(d); return d
    def readinto(self, b):
        d = self.read(len(b)); b[:len(d)] = d; return len(d)
z = zipfile.ZipFile(io.BufferedReader(RF(), 1 << 20))
infos = z.infolist(); print(len(infos), 'entries')
for i in infos:
    low = i.filename.lower()
    if any(low.endswith('/' + w.lower()) for w in wanted):
        print(i.filename, i.file_size, i.compress_size); z.extract(i, 'build')
