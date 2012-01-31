#!/usr/bin/python2

import os,sys,types
import argparse
import commands
import shutil

debug = False

mergeLog = open("/var/tmp/merge.log","w")

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

class ThirdPartyMirrors(MergeStep):

	def run(self,tree):
		orig = "%s/profiles/thirdpartymirrors" % tree.root
		new = "%s/profiles/thirdpartymirrors.new" % tree.root
		a = open(orig, "r")
		b = open(new, "w")
		for line in a:
			ls = line.split()
			if len(ls) and ls[0] == "gentoo":
				b.write("gentoo\t"+ls[1]+" http://www.funtoo.org/distfiles "+" ".join(ls[2:])+"\n")
			else:
				b.write(line)
		a.close()
		b.close()
		os.unlink(orig)
		os.link(new, orig)
		os.unlink(new)

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
		if not os.path.exists(dest):
			os.makedirs(dest)
		cmd = "rsync -a --exclude /.git --exclude .svn "
		for e in self.exclude:
			cmd += "--exclude %s " % e
		if self.delete:
			cmd += "--delete "
		cmd += "%s %s" % ( src, dest )
		runShell(cmd)

class SyncFiles(MergeStep): 
	def __init__(self, srcroot, files):
		self.srcroot = srcroot
		self.files = files
		if not isinstance(files, dict):
			raise TypeError("'files' argument should be a dict of source:destination items")

	def run(self, tree):
		for src, dest in self.files.items():
			if dest is not None:
				dest = os.path.join(tree.root, dest)
			else:
				dest = os.path.join(tree.root, src)
			src = os.path.join(self.srcroot, src)
			dest_dir = os.path.dirname(dest)
			if not os.path.exists(dest_dir):
				os.makedirs(dest_dir)
			shutil.copyfile(src, dest)

class CleanTree(MergeStep):
	# remove all files from tree, except dotfiles/dirs.
	def run(self,tree):
		for fn in os.listdir(tree.root):
			if fn[:1] == ".":
				continue
			runShell("rm -rf %s/%s" % (tree.root, fn))

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
			base = "/var/git/source-trees"
			self.root = "%s/%s" % ( base, self.name )
		if not os.path.exists(base):
			os.makedirs(base)
		if os.path.exists(self.root):
			runShell("(cd %s; git fetch origin)" % self.root )
			runShell("(cd %s; git checkout %s)" % ( self.root, self.branch ))
			if pull:
				runShell("(cd %s; git pull -f origin %s)" % ( self.root, self.branch ))
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

class SvnTree(object):
	def __init__(self, name, url=None, trylocal=None):
		self.name = name
		self.url = url
		self.trylocal = trylocal
		if self.trylocal and os.path.exists(self.trylocal):
			base = os.path.basename(self.trylocal)
			self.root = trylocal
		else:
			base = "/var/svn/source-trees"
			self.root = "%s/%s" % (base, self.name)
		if not os.path.exists(base):
			os.makedirs(base)
		if os.path.exists(self.root):
			runShell("(cd %s; svn up)" % self.root)
		else:
			runShell("(cd %s; svn co %s %s)" % (base, self.url, self.name))

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

	def __init__(self,srctree,select="all",skip=None,replace=False,merge=None,categories=None):
		self.select = select
		self.skip = skip
		self.srctree = srctree
		self.replace = replace
		self.merge = merge
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
				tcatdir = os.path.join(desttree.root,cat)
				tpkgdir = os.path.join(tcatdir,pkg)
				copy = False
				copied = False
				if self.replace == True or (type(self.replace) == types.ListType and "%s/%s" % (cat,pkg) in self.replace):
					if not os.path.exists(tcatdir):
						os.makedirs(tcatdir)
					if isinstance(self.merge, list) and "%s/%s" % (cat,pkg) in self.merge:
						pkgdir_manifest_file = open("%s/Manifest" % pkgdir)
						tpkgdir_manifest_file = open("%s/Manifest" % tpkgdir)
						pkgdir_manifest = pkgdir_manifest_file.readlines()
						tpkgdir_manifest = tpkgdir_manifest_file.readlines()
						pkgdir_manifest_file.close()
						tpkgdir_manifest_file.close()
						entries = {
							"AUX": {},
							"DIST": {},
							"EBUILD": {},
							"MISC": {}
						}
						for line in tpkgdir_manifest + pkgdir_manifest:
							if line.startswith(("AUX ", "DIST ", "EBUILD ", "MISC ")):
								entry_type = line.split(" ")[0]
								if entry_type in (("AUX", "DIST", "EBUILD", "MISC")):
									entries[entry_type][line.split(" ")[1]] = line
						runShell("cp -a %s %s" % (pkgdir, os.path.dirname(tpkgdir)))
						merged_manifest_file = open("%s/Manifest" % tpkgdir, "w")
						for entry_type in ("AUX", "DIST", "EBUILD", "MISC"):
							for key in sorted(entries[entry_type]):
								merged_manifest_file.write(entries[entry_type][key])
						merged_manifest_file.close()
					else:
						runShell("rm -rf %s; cp -a %s %s" % (tpkgdir, pkgdir, tpkgdir ))
					copied = True
				else:
					if not os.path.exists(tpkgdir):
						copied = True
					if not os.path.exists(tcatdir):
						os.makedirs(tcatdir)
					runShell("[ ! -e %s ] && cp -a %s %s || echo \"# skipping %s/%s\"" % (tpkgdir, pkgdir, tpkgdir, cat, pkg ))
				if copied:
					# log here.
					cpv = "/".join(tpkgdir.split("/")[-2:])
					mergeLog.write("%s\n" % cpv)

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


pull = True

parser = argparse.ArgumentParser(description="merge.py checks out funtoo.org's Gentoo tree, some developers overlays and the funtoo-overlay, and merges them to create Funtoo's unified Portage tree.")
parser.add_argument("--nopush", action="store_true", help="Prevents the script to push the git repositories")
parser.add_argument("--branch", default="master", help="The funtoo-overlay branch to use. Default: master.")
parser.add_argument("destination", nargs="+", help="The destination git repository.")

args = parser.parse_args()

if args.nopush:
	push = False
else:
	push = "origin funtoo.org"

dest = args.destination
for d in dest:
	if d[0] != "/":
		print("%s: Please specify destination git tree with an absolute path." % d)
		sys.exit(1)

branch = args.branch
