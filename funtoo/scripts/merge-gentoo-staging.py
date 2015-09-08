#!/usr/bin/python3

import os
from merge_utils import *

gentoo_staging_w = GitTree("gentoo-staging", "master", "repos@localhost:ports/gentoo-staging.git", root="/var/git/dest-trees/gentoo-staging", pull=False)

# shards are overlays where we collect gentoo's most recent changes. This way, we can merge specific versions rather than always be forced to
# get the latest.

perl_shard = GitTree("gentoo-perl-shard", "master", "repos@localhost:gentoo-perl-shard.git", root="/var/git/dest-trees/gentoo-perl-shard", pull=False)
python_shard = GitTree("gentoo-python-shard", "master", "repos@localhost:gentoo-python-shard.git", root="/var/git/dest-trees/gentoo-python-shard", pull=False)
kde_shard = GitTree("gentoo-kde-shard", "master", "repos@localhost:gentoo-kde-shard.git", root="/var/git/dest-trees/gentoo-kde-shard", pull=False)

# This function updates the gentoo-staging tree with all the latest gentoo updates:

def gentoo_staging_update():
	gentoo_use_rsync = False
	if gentoo_use_rsync:
		gentoo_src = RsyncTree("gentoo")
	else:
		gentoo_src = GitTree("gentoo-x86", "master", "https://anongit.gentoo.org/git/repo/gentoo.git", pull=True)
		#gentoo_src = CvsTree("gentoo-x86",":pserver:anonymous@anoncvs.gentoo.org:/var/cvsroot")
		gentoo_glsa = GitTree("gentoo-glsa", "master", "git://anongit.gentoo.org/data/glsa.git", pull=True)
	# This is the gentoo-staging tree, stored in a different place locally, so we can simultaneously be updating gentoo-staging and reading
	# from it without overwriting ourselves:
	all_steps = [
		GitCheckout("master"),
		SyncFromTree(gentoo_src, exclude=["metadata/.gitignore", "/metadata/cache/**", "ChangeLog", "dev-util/metro"]),
		# Only include 2012 and up GLSA's:
		SyncDir(gentoo_glsa.root, srcdir=None, destdir="metadata/glsa", exclude=["glsa-200*.xml","glsa-2010*.xml", "glsa-2011*.xml"]) if not gentoo_use_rsync else None,
	]

	perl_shard_steps = [
		GitCheckout("master"),
		CleanTree(),
		InsertEbuilds(gentoo_staging_w, select=re.compile("dev-perl/.*"), skip=None, replace=True),
		InsertEbuilds(gentoo_staging_w, select=re.compile("perl-core/.*"), skip=None, replace=True),
		InsertEbuilds(gentoo_staging_w, select=[ "dev-lang/perl" ], skip=None, replace=True),
		InsertEbuilds(gentoo_staging_w, select=re.compile("virtual/perl-.*"), skip=None, replace=True),
		SyncFiles(gentoo_staging_w.root, { "eclass/perl-app.eclass" : "eclass/perl-app.eclass", "eclass/perl-module.eclass" : "eclass/perl-module.eclass" })
	]
	python_shard_steps = [
		GitCheckout("master"),
		CleanTree(),
		InsertEbuilds(gentoo_staging_w, select=re.compile("dev-python/.*"), skip=None, replace=True),
		InsertEbuilds(gentoo_staging_w, select=[ "dev-lang/python", "dev-lang/python-exec" ], skip=None, replace=True),
		InsertEbuilds(gentoo_staging_w, select=re.compile("virtual/py.*"), skip=None, replace=True),
		InsertEclasses(gentoo_staging_w, select=re.compile("python.*\.eclass")),
		InsertEclasses(gentoo_staging_w, select=re.compile("gnome-python.*\.eclass")),
		
	]
	kde_shard_steps = [
		GitCheckout("master"),
		CleanTree(),
		InsertEbuilds(gentoo_staging_w, select=re.compile("dev-qt/.*"), skip=None, replace=True),
		InsertEbuilds(gentoo_staging_w, select=re.compile("kde-apps/.*"), skip=None, replace=True),
		InsertEbuilds(gentoo_staging_w, select=re.compile("kde-base/.*"), skip=None, replace=True),
		InsertEbuilds(gentoo_staging_w, select=re.compile("kde-frameworks/.*"), skip=None, replace=True),
		InsertEbuilds(gentoo_staging_w, select=re.compile("kde-misc/.*"), skip=None, replace=True),
		InsertEbuilds(gentoo_staging_w, select=re.compile("kde-plasma/.*"), skip=None, replace=True),
		InsertEclasses(gentoo_staging_w, select=re.compile("kde.*\.eclass")),
		InsertEclasses(gentoo_staging_w, select=re.compile("qt4-.*\.eclass")),
		InsertEclasses(gentoo_staging_w, select=re.compile("qt5-.*\.eclass")),
	]
	gentoo_staging_w.run(all_steps)
	gentoo_staging_w.gitCommit(message="gentoo updates", branch="master")
	perl_shard.run(perl_shard_steps)
	perl_shard.gitCommit(message="gentoo updates", branch="master")
	python_shard.run(python_shard_steps)
	python_shard.gitCommit(message="gentoo updates", branch="master")
	kde_shard.run(kde_shard_steps)
	kde_shard.gitCommit(message="gentoo updates", branch="master")

gentoo_staging_update()

# vim: ts=4 sw=4 noet
