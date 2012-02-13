#!/usr/bin/python

# This script will compare the versions of ebuilds in the funtoo portage tree against
# the versions of ebuilds in the target portage tree. Any higher versions in the 
# target Portage tree will be printed to stdout.

# Run this script from the root of the funtoo-overlay tree, specifying the target
# tree to compare against as an argument.

import portage.versions
import os,sys
try:
	import commands
except ImportError:
	import subprocess as commands

dirpath = os.path.dirname(os.path.realpath(__file__))
portdir = os.path.normpath(os.path.join(dirpath,"../.."))

print("List of differences between funtoo-overlay and gentoo")
print("=====================================================")

def getKeywords(portdir, ebuild, warn):
	a = commands.getstatusoutput(dirpath + "/keywords.sh %s %s" % ( portdir, ebuild ) )
	if a[0] == 0:
		my_set = set(a[1].split())
		if warn and len(my_set) == 0:
			print("WARNING: ebuild %s has no keywords" % ebuild)
		return (0, my_set)
	else:
		return a
	

if len(sys.argv) != 2:
	print("Please specify portage tree to compare against as first argument.")
	sys.exit(1)

gportdir=sys.argv[1]

def filterOnKeywords(portdir, ebuilds, keywords, warn=False):
	""" 
	This function accepts a path to a portage tree, a list of ebuilds, and a list of
	keywords. It will iteratively find the "best" version in the ebuild list (the most
	recent), and then manually extract this ebuild's KEYWORDS using the getKeywords()
	function. If at least one of the keywords in "keywords" cannot be found in the
	ebuild's KEYWORDS, then the ebuild is removed from the return list.

	Think of this function as "skimming the masked cream off the top" of a particular
	set of ebuilds. This way our list has been filtered somewhat and we don't have
	gcc-6.0 in our list just because someone added it masked to the tree. It makes
	comparisons fairer.
	"""

	filtered = ebuilds[:] 
	if len(ebuilds) == 0:
		return []
	cps = portage.versions.catpkgsplit(filtered[0])
	cat = cps[0]
	pkg = cps[1]
	keywords = set(keywords)
	while True:
		fbest = portage.versions.best(filtered)
		if fbest == "":
			break
		retval, fkeywords = getKeywords(portdir, "%s/%s/%s.ebuild" % (cat, pkg, fbest.split("/")[1] ), warn)
		if len(keywords & fkeywords) == 0:
			filtered.remove(fbest)
		else:
			break
	return filtered	

def get_cpv_in_portdir(portdir,cat,pkg):
	if not os.path.exists("%s/%s/%s" % (portdir, cat, pkg)):
		return []
	if not os.path.isdir("%s/%s/%s" % (portdir, cat, pkg)):
		return []
	files = os.listdir("%s/%s/%s" % (portdir, cat, pkg))
	ebuilds = []
	for file in files:
		if file[-12:] == "-9999.ebuild":
			continue
		if file[-7:] == ".ebuild":
			ebuilds.append("%s/%s" % (cat, file[:-7]))
	return ebuilds
	
def version_compare(portdir,gportdir,keywords):
	print("")
	print("Package comparison for %s" % keywords)
	print("============================================")
	print("(note that package.{un}mask(s) are ignored - looking at ebuilds only)")
	print("")

	for cat in os.listdir(portdir):
		if cat == ".git":
			continue
		if not os.path.exists(gportdir+"/"+cat):
			continue
		if not os.path.isdir(gportdir+"/"+cat):
			continue
		for pkg in os.listdir(os.path.join(portdir,cat)):
			ebuilds = get_cpv_in_portdir(portdir,cat,pkg)
			gebuilds = get_cpv_in_portdir(gportdir,cat,pkg)
			ebuilds = filterOnKeywords(portdir, ebuilds, keywords, warn=True)

			if len(ebuilds) == 0:
				continue
	
			fbest = portage.versions.best(ebuilds)
	
			gebuilds = filterOnKeywords(gportdir, gebuilds, keywords, warn=False)

			if len(gebuilds) == 0:
				continue

			gbest = portage.versions.best(gebuilds)
	
			if fbest == gbest:
				continue
		
			# a little trickery to ignore rev differences:
			fps = list(portage.versions.catpkgsplit(fbest))[1:]
			gps = list(portage.versions.catpkgsplit(gbest))[1:]
			gps[-1] = "r0"
			fps[-1] = "r0"
			
			mycmp = portage.versions.pkgcmp(fps, gps)
			if mycmp == -1:
				print("%s (vs. %s in funtoo)" % ( gbest, fbest ))

for keyw in [ "amd64", "~amd64", "x86", "~x86" ]:
	if keyw[0] == "~":
		# for unstable, add stable arch and ~* and * keywords too
		keyw = [ keyw, keyw[1:], "~*", "*"]
	else:
		# for stable, also consider the * keyword
		keyw = [ keyw, "*"]

	version_compare(portdir,gportdir,keyw)

