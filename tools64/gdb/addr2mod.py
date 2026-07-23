import gdb
class A2M(gdb.Command):
    def __init__(self): super().__init__("a2m", gdb.COMMAND_USER)
    def invoke(self, arg, from_tty):
        v = gdb.parse_and_eval(arg)
        rip = int(v)
        m = gdb.parse_and_eval("modlist")
        while int(m):
            code = int(m["code"]); csize = int(m["csize"])
            if code and code <= rip < code + csize:
                print("%#x = %s+%#x" % (rip, m["name"].string(errors="replace"), rip - code)); return
            m = m["next"]
        print("%#x not in any module" % rip)
A2M()
