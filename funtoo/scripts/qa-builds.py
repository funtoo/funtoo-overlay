#!/usr/bin/python3

from merge_utils import *

host="root@build.funtoo.org"
arch_desc="x86-64bit"
subarch="intel64-westmere"

funtoo_staging_r = GitTree("funtoo-staging", "master", "repos@localhost:ports/funtoo-staging.git", pull=True)
head = funtoo_staging_r.head()

#qa_build(host,"funtoo-current-xfce-next",arch_desc,subarch,head,"test")
qa_build(host,"funtoo-current-kde-next",arch_desc,subarch,head,"test")
#qa_build(host,"funtoo-current-gnome-next",arch_desc,subarch,head,"test")

