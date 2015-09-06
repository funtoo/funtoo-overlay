#!/usr/bin/python3

from merge_utils import *

host="root@build.funtoo.org"
arch_desc="x86-64bit"
subarch="intel64-westmere"

funtoo_staging_r = GitTree("funtoo-staging", "master", "repos@localhost:ports/funtoo-staging.git", pull=True)
head = funtoo_staging_r.head()
print(head)
success = False
if qa_build(host,"funtoo-current-next",arch_desc,subarch,head,"freshen"):
	if qa_build(host,"funtoo-stable-next",arch_desc,subarch,head,"freshen"):
		success = True
if not success:
	print("QA builds were not successful.")
	sys.exit(1)

ports_2012 = GitTree("ports-2012", "funtoo.org", "repos@localhost:ports-2012.git", root="/var/git/dest-trees/ports-2012", pull=False)

my_steps = [
	GitCheckout("funtoo.org"),
	SyncFromTree(funtoo_staging_r, exclude=["metadata/.gitignore"]),
	GenCache()
]

ports_2012.run(my_steps)
ports_2012.gitCommit(message="merged from funtoo-staging", branch="funtoo.org")
