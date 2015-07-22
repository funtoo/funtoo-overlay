#!/usr/bin/python3

import os
from merge_utils import *

gentoo_staging_w = GitTree("gentoo-staging", "master", "repos@localhost:ports/gentoo-staging.git", root="/var/git/dest-trees/gentoo-staging", pull=False)

# This function updates the gentoo-staging tree with all the latest gentoo updates:

def gentoo_staging_update():
	gentoo_use_rsync = False
	if gentoo_use_rsync:
		gentoo_src = RsyncTree("gentoo")
	else:
		gentoo_src = CvsTree("gentoo-x86",":pserver:anonymous@anoncvs.gentoo.org:/var/cvsroot")
		gentoo_glsa = GitTree("gentoo-glsa", "master", "git://anongit.gentoo.org/data/glsa.git", pull=True)
	# This is the gentoo-staging tree, stored in a different place locally, so we can simultaneously be updating gentoo-staging and reading
	# from it without overwriting ourselves:
	all_steps = [
		GitCheckout("master"),
		SyncFromTree(gentoo_src, exclude=["/metadata/cache/**", "ChangeLog", "dev-util/metro"]),
		# Only include 2012 and up GLSA's:
		SyncDir(gentoo_glsa.root, srcdir=None, destdir="metadata/glsa", exclude=["glsa-200*.xml","glsa-2010*.xml", "glsa-2011*.xml"]) if not gentoo_use_rsync else None,
	]
	gentoo_staging_w.run(all_steps)
	gentoo_staging_w.gitCommit(message="gentoo updates", branch="master")

gentoo_staging_update()
