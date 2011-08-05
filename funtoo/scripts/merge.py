#!/usr/bin/python2

import os,sys,types
import commands

debug = False

def headSHA1(tree):
	head = None
	hfile = os.path.join(tree,".git/HEAD")
	if os.path.exists(hfile):
		infile = open(hfile,"r")
		head = infile.readline().split()[1]
		infile.close()
		hfile2 = os.path.join(tree,".git")
		hfile2 = os.path.join(hfile2,head)
		if os.path.exists(hfile2):
			infile = open(hfile2,"r")
			head = infile.readline().split()[0]
	return head

def runShell(string,abortOnFail=True):
	if debug:
		print string
	else:
		print "running: %s" % string
		out = commands.getstatusoutput(string)
		if out[0] != 0:
			print "Error executing '%s'" % string
			print
			print "output:"
			print out[1]
			if abortOnFail:
				sys.exit(1)

class MergeStep(object):
	pass

class ApplyPatchSeries(MergeStep):
	def __init__(self,path):
		self.path = path

	def run(self,tree):
		a = open(os.path.join(self.path,"series"),"r")
		for line in a:
			if line[0:1] == "#":
				continue
			runShell( "( cd %s; git apply %s/%s )" % ( tree.root, self.path, line[:-1] ))

class SyncDir(MergeStep):
	def __init__(self,srcroot,srcdir=None,destdir=None,exclude=[],delete=False):
		self.srcroot = srcroot
		self.srcdir = srcdir
		self.destdir = destdir
		self.exclude = exclude
		self.delete = delete

	def run(self,tree):
		if self.srcdir:
			src = os.path.join(self.srcroot,self.srcdir)+"/"
		else:
			src = os.path.normpath(self.srcroot)+"/"
		if self.destdir:
			dest = os.path.join(tree.root,self.destdir)+"/"
		else:
			if self.srcdir:
				dest = os.path.join(tree.root,self.srcdir)+"/"
			else:
				dest = os.path.normpath(tree.root)+"/"
		cmd = "rsync -a --exclude /.git "
		for e in self.exclude:
			cmd += "--exclude %s " % e
		if self.delete:
			cmd += "--delete "
		cmd += "%s %s" % ( src, dest )
		runShell(cmd)

class SyncTree(SyncDir):
	# sync a full portage tree, deleting any excess files in the target dir:
	def __init__(self,srctree,exclude=[]):
		self.srctree = srctree
		SyncDir.__init__(self,srctree.root,srcdir=None,destdir=None,exclude=exclude,delete=True)
		
	def run(self,desttree):
		SyncDir.run(self,desttree)
		desttree.logTree(self.srctree)

class Tree(object):
	def __init__(self,name,branch="master",url=None,pull=False, trylocal=None):
		self.name = name
		self.branch = branch
		self.url = url
		self.merged = []
		self.trylocal = trylocal
		if self.trylocal and os.path.exists(self.trylocal):
			base = os.path.basename(self.trylocal)
			self.root = trylocal
		else:
			base = "/var/src/source-trees"
			self.root = "%s/%s" % ( base, self.name )
		if not os.path.exists(base):
			os.makedirs(base)
		if os.path.exists(self.root):
			runShell("(cd %s; git checkout %s)" % ( self.root, self.branch ))
			if pull:
				runShell("(cd %s; git pull origin %s)" % ( self.root, self.branch ))
		else:
			runShell("(cd %s; git clone %s %s)" % ( base, self.url, self.name ))
			runShell("(cd %s; git checkout %s)" % ( self.root, self.branch ))

	def head(self):
		return headSHA1(self.root)


	def logTree(self,srctree):
		# record name and SHA of src tree in dest tree, used for git commit message/auditing:
		if srctree.name == None:
			# this tree doesn't have a name, so just copy any existing history from that tree
			self.merged.extend(srctree.merged)
		else:
			# this tree has a name, so record the name of the tree and its SHA1 for reference
			self.merged.append([srctree.name, headSHA1(srctree.root)])

class UnifiedTree(Tree):
	def __init__(self,root,steps):
		self.steps = steps
		self.root = root
		self.name = None
		self.merged = []

	def run(self):
		for step in self.steps:
			step.run(self)

	def gitCommit(self,message="",push=False):
		runShell("( cd %s; git add . )" % self.root )
		cmd = "( cd %s; [ -n \"$(git status --porcelain)\" ] && git commit -a -F - << EOF || exit 0\n" % self.root
		if message != "":
			cmd += "%s\n\n" % message
		cmd += "merged: \n\n"
		for name, sha1 in self.merged:
			if sha1 != None:
				cmd += "  %s: %s\n" % ( name, sha1 )
		cmd += "EOF\n"
		cmd += ")\n" 
		print "running: %s" % cmd
		# we use os.system because this multi-line command breaks runShell() - really, breaks commands.getstatusoutput().
		retval = os.system(cmd)
		if retval != 0:
			print "Commit failed."
			sys.exit(1)
		if push != False:
			runShell("(cd %s; git push %s)" % ( self.root, push )) 
	

class InsertEbuilds(MergeStep):

	def __init__(self,srctree,select="all",skip=None,replace=False,update=False,categories=None):
		self.select = select
		self.skip = skip
		self.srctree = srctree
		self.replace = replace
		self.update = update
		self.categories = categories
	
	def run(self,desttree):
		desttree.logTree(self.srctree)
		# Figure out what categories to process:
		catpath = os.path.join(self.srctree.root,"profiles/categories")
		if self.categories != None:
			# categories specified in __init__:
			a = self.categories
		else:
			a = []
			if os.path.exists(catpath):
				# categories defined in profile:
				f = open(os.path.join(self.srctree.root,"profiles/categories"),"r")
				for cat in f.readlines():
					cat = cat.strip()
					if cat not in a:
						a.append(cat)
				f.close()
			# auto-detect additional categories:
			cats = os.listdir(self.srctree.root)
			for cat in cats:
				# All categories have a "-" in them and are directories:
				if os.path.isdir(os.path.join(self.srctree.root,cat)):
					if (cat.find("-") != -1) or cat == "virtuals":
						if cat not in a:
							a.append(cat)

		# Our main loop:
		print "# Merging in ebuilds from %s" % self.srctree.root 
		for cat in a:
			catdir = os.path.join(self.srctree.root,cat)
			if not os.path.isdir(catdir):
				# not a valid category in source overlay, so skip it
				continue
			#runShell("install -d %s" % catdir)
			for pkg in os.listdir(catdir):
				catpkg = "%s/%s" % (cat,pkg)
				pkgdir = os.path.join(catdir, pkg)
				if not os.path.isdir(pkgdir):
					# not a valid package dir in source overlay, so skip it
					continue
				if type(self.select) == types.ListType and catpkg not in self.select:
					# we have a list of pkgs to merge, and this isn't on the list, so skip:
					continue
				if type(self.skip) == types.ListType and catpkg in self.skip:
					# we have a list of pkgs to skip, and this catpkg is on the list, so skip:
					continue
				tpkgdir = os.path.join(desttree.root,cat)
				tpkgdir = os.path.join(tpkgdir,pkg)
				copy = False
				if self.replace == True or (type(self.replace) == types.ListType and "%s/%s" % (cat,pkg) in self.replace):
					runShell("rm -rf %s; cp -a %s %s" % (tpkgdir, pkgdir, tpkgdir ))
				else:
					if self.update == False:
						runShell("[ ! -e %s ] && cp -a %s %s || echo \"# skipping %s/%s\"" % (tpkgdir, pkgdir, tpkgdir, cat, pkg ))
					else:
						# If the target directory does not exist, we create it. 
						runShell("[ ! -e %s ] && mkdir %s || echo \"# updating %s/%s\"" % (tpkgdir, tpkgdir, cat, pkg))

						# We create a dummy Manifest file if it doesn't exist.
						runShell("[ ! -e %s/Manifest ] && touch %s/Manifest || echo \"# creating dummy manifest\"" % (tpkgdir, tpkgdir))

						# We backup the target Manifest file.
						runShell("mv %s/Manifest %s/Manifest.bkp" % (tpkgdir, tpkgdir))

						# We copy the files from the source directory to the target directory.
						runShell("cp -a %s/* %s" % (pkgdir, tpkgdir))

						# We merge the two Manifest files
						fOldManifest = open("%s/Manifest.bkp" % (tpkgdir ))
						fNewManifest = open("%s/Manifest" % (tpkgdir ))
						lOldManifest = fOldManifest.readlines()
						lNewManifest = fNewManifest.readlines()

						# We remove from the old manifest the entries that are in the new manifest.
						uniqueOldEntries = [l for l in lOldManifest if not l.split()[:2] in [l2.split()[:2] for l2 in lNewManifest]]

						# We merge and sort the cleaned old manifest and the new manifest.
						mergedEntries = uniqueOldEntries + lNewManifest
						mergedEntries.sort()
						fNewManifest = open("%s/Manifest" % (tpkgdir ), "w")
						fNewManifest.writelines(mergedEntries)

						# We delete the old Manifest file.
						runShell("rm %s/Manifest.bkp" % (tpkgdir))

class ProfileDepFix(MergeStep):

	def run(self,tree):
		fpath = os.path.join(tree.root,"profiles/profiles.desc")
		if os.path.exists(fpath):
			a = open(fpath,"r")
			for line in a:
				if line[0:1] == "#":
					continue
				sp = line.split()
				if len(sp) >= 2:
					prof_path = sp[1]
					runShell("rm -f %s/profiles/%s/deprecated" % ( tree.root, prof_path ))

class GenCache(MergeStep):
	def run(self,tree):
		runShell("egencache --update --portdir=%s --jobs=12" % tree.root, abortOnFail=False)

class GitPrep(MergeStep):
	def __init__(self,branch):
		self.branch = branch

	def run(self,tree):
		runShell("( cd %s; git checkout %s )" % ( tree.root, self.branch ))

class Minify(MergeStep):
	def run(self,tree):
		runShell("( cd %s; find -iname ChangeLog -exec rm -f {} \; )" % tree.root )
		runShell("( cd %s; find -iname Manifest -exec sed -n -i -e \"/DIST/p\" {} \; )" % tree.root )


# CHANGE TREE CONFIGURATION BELOW:

pull = True
if len(sys.argv) > 1 and "nopush" in sys.argv[1:]:
	push = False
else:
	push = "origin funtoo.org"

gentoo_src = Tree("gentoo","gentoo.org", "git://github.com/funtoo/portage.git", pull=True, trylocal="/var/git/portage-gentoo")
funtoo_overlay = Tree("funtoo-overlay", "master", "git://github.com/funtoo/funtoo-overlay.git", pull=True)
foo_overlay = Tree("foo-overlay", "master", "https://github.com/slashbeast/foo-overlay.git", pull=True)
bar_overlay = Tree("bar-overlay", "master", "git://github.com/adessemond/bar-overlay.git", pull=True)
flora_overlay = Tree("flora", "master", "https://github.com/funtoo/flora.git", pull=True)
felicitus_overlay = Tree("felicitus-overlay", "master", "https://github.com/timoahummel/felicitus_overlay.git", pull=True)

if len(sys.argv) > 1 and sys.argv[1][0] == "/":
	dest = sys.argv[1]
	dest_mini_2010 = None
	dest_mini = sys.argv[1]+"-mini"
	branch = "funtoo.org" 
else:
	dest = "/var/git/portage-prod"
	dest_mini_2010 = "/var/git/portage-mini-2010"
	dest_mini = "/var/git/portage-mini-2011"
	branch = "funtoo.org"

for test in [ dest, dest_mini ]:
	if not os.path.isdir(test):
		os.makedirs(test)
	if not os.path.isdir("%s/.git" % test):
		runShell("( cd %s; git init )" % test )
		runShell("echo 'created by merge.py' > %s/README" % test )
		runShell("( cd %s; git add README; git commit -a -m 'initial commit by merge.py' )" % test )
		runShell("( cd %s; git checkout -b funtoo.org; git rm -f README; git commit -a -m 'initial funtoo.org commit' )" % test )
		print("Pushing disabled automatically because repository created from scratch.")
		push = False

steps = [
	SyncTree(gentoo_src,exclude=["/metadata/cache/**"]),
	ApplyPatchSeries("%s/funtoo/patches" % funtoo_overlay.root ),
	SyncDir(funtoo_overlay.root,"profiles","profiles", exclude=["repo_name","categories"]),
	ProfileDepFix(),
	SyncDir(funtoo_overlay.root,"licenses"),
	SyncDir(funtoo_overlay.root,"eclass"),
	InsertEbuilds(funtoo_overlay, select="all", skip=None, replace=True),
	InsertEbuilds(foo_overlay, select="all", skip=None, replace=["app-shells/rssh"]),
	InsertEbuilds(bar_overlay, select="all", skip=None, replace=True),
	InsertEbuilds(flora_overlay, select="all", skip=None, replace=False),
	InsertEbuilds(felicitus_overlay, select="all", skip=None, replace=False),
	GenCache()
]

# work tree is a non-git tree in tmpfs for enhanced performance - we do all the heavy lifting there:

work = UnifiedTree("/var/src/merge-portage-work",steps)
work.run()

steps = [
	GitPrep(branch),
	SyncTree(work)
]

# then for the production tree, we rsync all changes on top of our prod git tree and commit:

prod = UnifiedTree(dest,steps)
prod.run()
prod.gitCommit(message="glorious funtoo updates",push=push)

# then for the mini tree, we rsync all work changes on top of our mini git tree, minify, and commit:

minis = [ dest_mini ]
if dest_mini_2010 != None:
	minis.append(dest_mini_2010)

for d_mini in minis:
	mini = UnifiedTree( d_mini, [
		GitPrep(branch), 
		SyncTree(work, exclude=["ChangeLog"]), 
		Minify() 
	])

	mini.run()
	mini.gitCommit(message="glorious funtoo updates",push=push)


