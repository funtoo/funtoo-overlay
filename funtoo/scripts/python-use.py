#!/usr/bin/python

import portage
import subprocess
import os

p = portage.db[portage.root]["porttree"].dbapi
subdir = "output"

def do_package_use_line(pkg, imps):
    if "python3_3" not in imps:
        if "python2_7" in imps:
            print("%s python_single_target_python2_7" % pkg)
        else:
            print("%s python_single_target_%s python_targets_%s" % (pkg, imps[0], imps[0]))

for pkg in p.cp_all():
    cp = portage.catsplit(pkg)
    ebs = {}
    for a in p.xmatch("match-all", pkg):
        if len(a) == 0:
            continue
        aux = p.aux_get(a, ["INHERITED"])
        eclasses=aux[0].split()
        if "python-single-r1" not in eclasses:
            continue
        else:
            px = portage.catsplit(a)
            cmd = '( eval $(cat /usr/portage/%s/%s/%s.ebuild | grep ^PYTHON_COMPAT); echo "${PYTHON_COMPAT[@]}" )' % ( cp[0], cp[1], px[1] )
            outp = subprocess.getstatusoutput(cmd)
            imps = outp[1].split()
            ebs[a] = imps
    if len(ebs.keys()) == 0:
        continue

    # ebs now is a dict containing catpkg -> PYTHON_COMPAT settings for each ebuild in the catpkg. We want to see if they are identical
    oldval = None
    split = False
    for key,val in ebs.items():
        if oldval == None:
            oldval = val
        else:
            if oldval != val:
                split = True
                break

    if not split:
        do_package_use_line(pkg, oldval)
    else:
        for key,val in ebs.items():
            do_package_use_line("=%s" % key, val)


