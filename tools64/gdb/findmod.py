import gdb
class FindMod(gdb.Command):
    def __init__(self): super().__init__("findmod", gdb.COMMAND_USER)
    def invoke(self, arg, from_tty):
        rip = int(gdb.parse_and_eval("$rip"))
        print("rip = %#x" % rip)
        m = gdb.parse_and_eval("modlist")
        best = None
        while True:
            try:
                if int(m) == 0: break
                code = int(m["code"]); csize = int(m["csize"])
                name = m["name"].string(errors="replace")
            except gdb.error:
                break
            if code and code <= rip < code + csize:
                print("HIT: %s code=%#x csize=%#x offset=%#x" % (name, code, csize, rip - code))
                return
            if code and code < rip and (best is None or code > best[1]):
                best = (name, code, csize)
            m = m["next"]
        if best: print("nearest below: %s code=%#x csize=%#x rip-code=%#x" % (best[0], best[1], best[2], rip - best[1]))
        else: print("no module found")
FindMod()
