#!/usr/bin/python2

from merge_utils import *

gentoo_src = Tree("gentoo","gentoo.org", "git://github.com/funtoo/portage.git", pull=True, trylocal="/var/git/portage-gentoo")
funtoo_overlay = Tree("funtoo-overlay", branch, "git://github.com/funtoo/funtoo-overlay.git", pull=True)
foo_overlay = Tree("foo-overlay", "master", "https://github.com/slashbeast/foo-overlay.git", pull=True)
bar_overlay = Tree("bar-overlay", "master", "git://github.com/adessemond/bar-overlay.git", pull=True)
flora_overlay = Tree("flora", "master", "https://github.com/funtoo/flora.git", pull=True)

steps = [
	SyncTree(gentoo_src,exclude=["/metadata/cache/**","ChangeLog", "dev-util/metro"]),
	ApplyPatchSeries("%s/funtoo/patches" % funtoo_overlay.root ),
	ThirdPartyMirrors(),
	SyncDir(funtoo_overlay.root,"profiles","profiles", exclude=["repo_name","categories"]),
	ProfileDepFix(),
	SyncDir(funtoo_overlay.root,"licenses"),
	SyncDir(funtoo_overlay.root,"eclass"),
	SyncDir(funtoo_overlay.root,"metadata"),
	InsertEbuilds(funtoo_overlay, select="all", skip=None, replace=True),
	InsertEbuilds(foo_overlay, select="all", skip=None, replace=["app-shells/rssh","net-misc/unison"]),
	InsertEbuilds(bar_overlay, select="all", skip=None, replace=True),
	InsertEbuilds(flora_overlay, select="all", skip=None, replace=False)
]
if branch == "experimental":
	if not os.path.exists("/usr/bin/svn"):
		print("svn binary not found at /usr/bin/svn. Exiting.")
		sys.exit(1)
	progress_overlay = SvnTree("progress", "https://gentoo-progress.googlecode.com/svn/overlays/progress")
	steps.extend((
		SyncDir(progress_overlay.root, "eclass"),
		SyncFiles(progress_overlay.root, {
			"profiles/package.mask":"profiles/package.mask/progress",
			"profiles/use.mask":"profiles/use.mask/progress"
		}),
		InsertEbuilds(progress_overlay, select="all", skip=None, replace=True, merge=["dev-lang/python", "dev-libs/boost", "dev-python/psycopg", "dev-python/pysqlite", "dev-python/python-docs", "dev-python/simpletal", "dev-python/wxpython", "x11-libs/vte"])
	))
steps.extend((
	Minify(),
	GenCache()
))

# work tree is a non-git tree in tmpfs for enhanced performance - we do all the heavy lifting there:

work = UnifiedTree("/var/src/merge-%s" % os.path.basename(dest[0]),steps)
work.run()

steps = [
	GitPrep("funtoo.org"),
	SyncTree(work)
]

# then for the production tree, we rsync all changes on top of our prod git tree and commit:

for d in dest:
	if not os.path.isdir(d):
		os.makedirs(d)
	if not os.path.isdir("%s/.git" % d):
		runShell("( cd %s; git init )" % d )
		runShell("echo 'created by merge.py' > %s/README" % d )
		runShell("( cd %s; git add README; git commit -a -m 'initial commit by merge.py' )" % d )
		runShell("( cd %s; git checkout -b funtoo.org; git rm -f README; git commit -a -m 'initial funtoo.org commit' )" % ( d ) )
		print("Pushing disabled automatically because repository created from scratch.")
		push = False
	prod = UnifiedTree(d,steps)
	prod.run()
	prod.gitCommit(message="glorious funtoo updates",push=push)
