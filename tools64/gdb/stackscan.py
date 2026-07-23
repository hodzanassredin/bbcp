import gdb
class StackScan(gdb.Command):
    def __init__(self): super().__init__("stackscan", gdb.COMMAND_USER)
    def invoke(self, arg, from_tty):
        mods = []
        m = gdb.parse_and_eval("modlist")
        while True:
            try:
                if int(m) == 0: break
                mods.append((int(m["code"]), int(m["csize"]), m["name"].string(errors="replace")))
                m = m["next"]
            except gdb.error: break
        rsp = int(gdb.parse_and_eval("$rsp"))
        for off in range(0, 0x400, 8):
            try: val = int(gdb.parse_and_eval("*(long*)(%#x+%d)" % (rsp, off)))
            except gdb.error: continue
            for code, csize, name in mods:
                if code and code <= val < code + csize:
                    print("rsp+%#05x -> %s+%#x" % (off, name, val - code))
                    break
StackScan()
