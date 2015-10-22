#!/usr/bin/python

import portage
import subprocess
import os

p = portage.db[portage.root]["porttree"].dbapi
subdir = "output"

for pkg in p.cp_all():
    cp = portage.catsplit(pkg)
    a = p.xmatch("bestmatch-visible", pkg)
    if a == '':
        continue
    aux = p.aux_get(a, ["INHERITED"])
    eclasses=aux[0].split()
    if "python-single-r1" in eclasses:
        px = portage.catsplit(a)
        cmd = '( eval $(cat /usr/portage/%s/%s/%s.ebuild | grep ^PYTHON_COMPAT); echo "${PYTHON_COMPAT[@]}" )' % ( cp[0], cp[1], px[1] )
        outp = subprocess.getstatusoutput(cmd)
        imps = outp[1].split()
        if "python3_3" not in imps:
            if "python2_7" in imps:
                print("%s python_single_target_python2_7" % pkg)
            else:
                print("%s python_single_target_%s python_targets_%s" % (pkg, imps[0], imps[0]))