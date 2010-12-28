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

def runShell(string):
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
	def __init__(self,name,root,pull=False):
		self.name = name
		self.root = root
		self.merged = []
		if pull:
			runShell("(cd %s; git pull)" % self.root)		

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
		Tree.__init__(self,name=None,root=root,pull=False)

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

	def __init__(self,srctree,replace=False,categories=None):
		self.srctree = srctree
		self.replace = replace
		self.categories = categories

	def run(self,desttree):
		desttree.logTree(self.srctree)
		# Figure out what categories to process:
		catpath = os.path.join(self.srctree.root,"profiles/categories")

		if self.categories != None:
			# categories specified in __init__:
			a = self.categories
		elif os.path.exists(catpath):
			# categories defined in profile:
			a = []
			f = open(os.path.join(self.srctree.root,"profiles/categories"),"r")
			for cat in f.readlines():
				a.append(cat.strip())
			f.close()
		else:
			# no categories specified to __init__, and no profiles/categories file, so auto-detect categories:
			a = []
			cats = os.listdir(self.srctree.root)
			for cat in cats:
				# All categories have a "-" in them and are directories:
				if os.path.isdir(os.path.join(self.srctree.root,cat)) and cat.find("-") != -1:
					a.append(cat)

		# Our main loop:
		print "# Merging in ebuilds from %s" % self.srctree.root 
		for cat in a:
			catdir = os.path.join(self.srctree.root,cat)
			if not os.path.isdir(catdir):
				# not a valid category in source overlay, so skip it
				continue
			runShell("install -d %s" % catdir)
			for pkg in os.listdir(catdir):
				pkgdir = os.path.join(catdir, pkg)
				if not os.path.isdir(pkgdir):
					# not a valid package dir in source overlay, so skip it
					continue
				tpkgdir = os.path.join(desttree.root,cat)
				tpkgdir = os.path.join(tpkgdir,pkg)
				copy = False
				if self.replace == True or (type(self.replace) == types.ListType and "%s/%s" % (cat,pkg) in self.replace):
					runShell("rm -rf %s; cp -a %s %s" % (tpkgdir, pkgdir, tpkgdir ))
				else:
					runShell("[ ! -e %s ] && cp -a %s %s || echo \"# skipping %s/%s\"" % (tpkgdir, pkgdir, tpkgdir, cat, pkg ))

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
		runShell("egencache --update --portdir=%s --jobs=12" % tree.root)

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
if len(sys.argv) > 1 and sys.argv[1] == "nopush":
	push = False
else:
	push = "origin funtoo.org"

gentoo_src = Tree("gentoo","/var/git/portage-gentoo")
funtoo_overlay = Tree("funtoo-overlay", "/root/git/funtoo-overlay",pull=True)
tarsius_overlay = Tree("tarsius-overlay", "/root/git/tarsius-overlay",pull=True)

steps = [
	SyncTree(gentoo_src,exclude=["/metadata/cache/**"]),
	ApplyPatchSeries("%s/funtoo/patches" % funtoo_overlay.root ),
	SyncDir(funtoo_overlay.root,"profiles","profiles", exclude=["repo_name","categories"]),
	ProfileDepFix(),
	SyncDir(funtoo_overlay.root,"licenses"),
	SyncDir(funtoo_overlay.root,"eclass"),
	InsertEbuilds(funtoo_overlay, replace=True),
	InsertEbuilds(tarsius_overlay, replace=["sys-libs/libixp","x11-wm/wmii","dev-vcs/cvsps", "net-print/foo2zjs"]),
	GenCache()
]

# work tree is a non-git tree in tmpfs for enhanced performance - we do all the heavy lifting there:

work = UnifiedTree("/var/src/merge-portage-work",steps)
work.run()

steps = [
	GitPrep("funtoo.org"),
	SyncTree(work)
]

# then for the production tree, we rsync all changes on top of our prod git tree and commit:

prod = UnifiedTree("/var/git/portage-prod",steps)
prod.run()
prod.gitCommit(message="glorious funtoo updates",push=push)

# then for the mini tree, we rsync all work changes on top of our mini git tree, minify, and commit:

mini = UnifiedTree("/var/git/portage-mini-2010", [ 
	GitPrep("funtoo.org"), 
	SyncTree(work, exclude=["ChangeLog"]), 
	Minify() 
])

mini.run()
mini.gitCommit(message="glorious funtoo updates",push=push)

