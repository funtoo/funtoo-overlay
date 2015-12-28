#!/usr/bin/python3

import os
import sys
from merge_utils import *

xml_out = etree.Element("packages")
funtoo_staging_w = GitTree("funtoo-staging", "master", "repos@localhost:ports/funtoo-staging.git", root="/var/git/dest-trees/funtoo-staging", pull=False, xml_out=xml_out)
#funtoo_staging_w = GitTree("funtoo-staging-unfork", "master", "repos@localhost:ports/funtoo-staging-unfork.git", root="/var/git/dest-trees/funtoo-staging-unfork", pull=False, xml_out=None)
xmlfile="/home/ports/public_html/packages.xml"

nopush=False

funtoo_overlay = GitTree("funtoo-overlay", "master", "repos@localhost:funtoo-overlay.git", pull=True)

# We treat our Gentoo staging overlay specially, so it's listed separately. This overlay contains all Gentoo
# ebuilds, in a git repository. We use a special file in the funtoo-overlay/funtoo/scripts directory (next to
# this file) to provide a SHA1 of the commit of the gentoo-staging overlay that we want to use as a basis
# for our merges. Let's grab the SHA1 hash from that file:
	
p = os.path.join(funtoo_overlay.root,"funtoo/scripts/commit-staged")
if os.path.exists(p):
	a = open(p,"r")
	commit = a.readlines()[0].strip()
	print("Using commit: %s" % commit)
else:
	commit = None

gentoo_staging_r = GitTree("gentoo-staging", "master", "repos@localhost:ports/gentoo-staging.git", commit=commit, pull=True)

# These overlays are monitored for changes -- if there are changes in these overlays, we regenerate the entire
# tree. If there aren't changes in these overlays, we don't.

shards = {
	"perl" : GitTree("gentoo-perl-shard", "fb72db8da6e7418282e61105dfe0b4e16d98f892", "repos@localhost:gentoo-perl-shard.git", pull=True),
	"kde" : GitTree("gentoo-kde-shard", "41c45a1313d8456e0060b86e0b3ef5fae100c1da", "repos@localhost:gentoo-kde-shard.git", pull=True),
	"gnome" : GitTree("gentoo-gnome-shard", "4d5473019d599229cb54edde7f5a7e48df46302f", "repos@localhost:ports/gentoo-gnome-shard.git", pull=True),
	"x11" : GitTree("gentoo-x11-shard", "aea19ce1b589357f579829ed719e6c062f747d2f", "repos@localhost:ports/gentoo-x11-shard.git", pull=True),
	"core" : GitTree("gentoo-core-shard", "4a25cdbce1e664f3472aa0f52ea6c528a26d3045", "repos@localhost:gentoo-core-shard.git", pull=True)
}

# perl:	fb72db8da6e7418282e61105dfe0b4e16d98f892 (Updated 26 Dec 2015)
# kde: 41c45a1313d8456e0060b86e0b3ef5fae100c1da  (Updated 17 Dec 2015)
# gnome: 4d5473019d599229cb54edde7f5a7e48df46302f (Updated 5 Oct 2015)
# x11: aea19ce1b589357f579829ed719e6c062f747d2f (Updated 15 Dec 2015)
# core: 4a25cdbce1e664f3472aa0f52ea6c528a26d3045 (Updated 8 Dec 2015)

funtoo_overlays = {
	"funtoo_media" : GitTree("funtoo-media", "master", "repos@localhost:funtoo-media.git", pull=True),
	"plex_overlay" : GitTree("funtoo-plex", "master", "https://github.com/Ghent/funtoo-plex.git", pull=True),
	"gnome_fixups" : GitTree("gnome-3.16-fixups", "master", "repos@localhost:ports/gnome-3.16-fixups.git", pull=True),
	"funtoo_toolchain" : GitTree("funtoo-toolchain", "master", "repos@localhost:funtoo-toolchain-overlay.git", pull=True),
	"ldap_overlay" : GitTree("funtoo-ldap", "master", "repos@localhost:funtoo-ldap-overlay.git", pull=True),
	"deadbeef_overlay" : GitTree("deadbeef-overlay", "master", "https://github.com/damex/deadbeef-overlay.git", pull=True),
	"gambas_overlay" : GitTree("gambas-overlay", "master", "https://github.com/damex/gambas-overlay.git", pull=True),
	"wmfs_overlay" : GitTree("wmfs-overlay", "master", "https://github.com/damex/wmfs-overlay.git", pull=True),
}

# These are other overlays that we merge into the Funtoo tree. However, we just pull in the most recent versions
# of these when we regenerate our tree.

other_overlays = {
	"foo_overlay" : GitTree("foo-overlay", "master", "https://github.com/slashbeast/foo-overlay.git", pull=True),
	"bar_overlay" : GitTree("bar-overlay", "master", "git://github.com/adessemond/bar-overlay.git", pull=True),
	"causes_overlay" : GitTree("causes","master", "https://github.com/causes-/causelay", pull=True),
	"bliss_overlay" : GitTree("bliss-overlay", "master", "https://github.com/fearedbliss/bliss-overlay.git", pull=True),
	"squeezebox_overlay" : GitTree("squeezebox", "master", "git://anongit.gentoo.org/user/squeezebox.git", pull=True),
	"pantheon_overlay" : GitTree("pantheon", "master", "https://github.com/pimvullers/elementary.git", pull=True),
	"pinsard_overlay" : GitTree("pinsard", "master", "https://github.com/apinsard/sapher-overlay.git", pull=True),
	"sabayon_for_gentoo" : GitTree("sabayon-for-gentoo", "master", "git://github.com/Sabayon/for-gentoo.git", pull=True),
	"tripsix_overlay" : GitTree("tripsix", "master", "https://github.com/666threesixes666/tripsix.git", pull=True),
	"faustoo_overlay" : GitTree("faustoo", "master", "https://github.com/fmoro/faustoo.git", pull=True),
	"vmware_overlay" : GitTree("vmware", "master", "git://anongit.gentoo.org/proj/vmware.git", pull=True)
}

funtoo_changes = False
if funtoo_overlay.changes:
	funtoo_changes = True
elif gentoo_staging_r.changes:
	funtoo_changes = True
else:
	for fo in funtoo_overlays:
		if funtoo_overlays[fo].changes:
			funtoo_changes = True
			break

# This next code regenerates the contents of the funtoo-staging tree. Funtoo's tree is itself composed of
# many different overlays which are merged in an automated fashion. This code does it all.

pull = True

if nopush:
	push = False
else:
	push = "master"

# base_steps define the initial steps that prepare our destination tree for writing. Checking out the correct
# branch, copying almost the full entirety of Gentoo's portage tree to our destination tree, and copying over
# funtoo overlay licenses, metadata, and also copying over GLSA's.

base_steps = [
	GitCheckout("master"),
	SyncFromTree(gentoo_staging_r, exclude=[ 
		"/metadata/cache/**",
		"ChangeLog",
		"dev-util/metro",
		"skel.ChangeLog",
	]),
]

# Steps related to generating system profiles. These can be quite order-dependent and should be handled carefully.
# Generally, the funtoo_overlay sync should be first, then the gentoo_staging_r SyncFiles, which overwrites some stub
# files in the funtoo overlay.

profile_steps = [
	SyncDir(funtoo_overlay.root, "profiles", "profiles", exclude=["categories", "updates"]),
	CopyAndRename("profiles/funtoo/1.0/linux-gnu/arch/x86-64bit/subarch", "profiles/funtoo/1.0/linux-gnu/arch/pure64/subarch", lambda x: os.path.basename(x) + "-pure64"),
	SyncFiles(gentoo_staging_r.root, {
		"profiles/package.mask":"profiles/package.mask/00-gentoo",
		"profiles/arch/amd64/package.use.mask":"profiles/funtoo/1.0/linux-gnu/arch/x86-64bit/package.use.mask/01-gentoo",
		"profiles/features/multilib/package.use.mask":"profiles/funtoo/1.0/linux-gnu/arch/x86-64bit/package.use.mask/02-gentoo",
		"profiles/arch/amd64/use.mask":"profiles/funtoo/1.0/linux-gnu/arch/x86-64bit/use.mask/01-gentoo",
		"profiles/arch/x86/package.use.mask":"profiles/funtoo/1.0/linux-gnu/arch/x86-32bit/package.use.mask/01-gentoo",
		"profiles/arch/x86/use.mask":"profiles/funtoo/1.0/linux-gnu/arch/x86-32bit/use.mask/01-gentoo",
		"profiles/default/linux/package.use.mask":"profiles/funtoo/1.0/linux-gnu/package.use.mask/01-gentoo",
		"profiles/default/linux/use.mask":"profiles/funtoo/1.0/linux-gnu/use.mask/01-gentoo",
		"profiles/arch/amd64/no-multilib/package.use.mask":"profiles/funtoo/1.0/linux-gnu/arch/pure64/package.use.mask/01-gentoo",
		"profiles/arch/amd64/no-multilib/package.mask":"profiles/funtoo/1.0/linux-gnu/arch/pure64/package.mask/01-gentoo",
		"profiles/arch/amd64/no-multilib/use.mask":"profiles/funtoo/1.0/linux-gnu/arch/pure64/use.mask/01-gentoo"
	}),
	SyncFiles(funtoo_overlays["deadbeef_overlay"].root, {
		"profiles/package.mask":"profiles/package.mask/deadbeef-mask"
	}),
	SyncFiles(funtoo_overlays["wmfs_overlay"].root, {
		"profiles/package.mask":"profiles/package.mask/wmfs-mask"
	}) ]

profile_steps += [
	SyncFiles(funtoo_overlays["funtoo_toolchain"].root, {
		"profiles/package.mask/funtoo-toolchain":"profiles/funtoo/1.0/linux-gnu/build/current/package.mask/funtoo-toolchain",
	}),
	SyncFiles(funtoo_overlays["funtoo_toolchain"].root, {
		"profiles/package.mask/funtoo-toolchain":"profiles/funtoo/1.0/linux-gnu/build/stable/package.mask/funtoo-toolchain",
		"profiles/package.mask/funtoo-toolchain-experimental":"profiles/funtoo/1.0/linux-gnu/build/experimental/package.mask/funtoo-toolchain",
	}),
	RunSed(["profiles/base/make.defaults"], ["/^PYTHON_TARGETS=/d", "/^PYTHON_SINGLE_TARGET=/d"]),
]

# Steps related to copying ebuilds. Note that order can make a difference here when multiple overlays are
# providing identical catpkgs.

# Ebuild additions -- these are less-risky changes because ebuilds are only added, and not replaced.

ebuild_additions = [
	InsertEbuilds(other_overlays["bar_overlay"], select="all", skip=["app-emulation/qemu"], replace=False),
	InsertEbuilds(other_overlays["bliss_overlay"], select="all", skip=["net-p2p/bittorrent-sync", "media-tv/plex-media-server", "app-bin/firefox", "app-bin/libreoffice"], replace=False),
	InsertEbuilds(other_overlays["squeezebox_overlay"], select="all", skip=None, replace=False),
	InsertEbuilds(funtoo_overlays["deadbeef_overlay"], select="all", skip=None, replace=False),
	InsertEbuilds(funtoo_overlays["gambas_overlay"], select="all", skip=None, replace=False),
	InsertEbuilds(funtoo_overlays["wmfs_overlay"], select="all", skip=None, replace=False),
	]

# Ebuild modifications -- these changes need to be treated more carefully as ordering can be important
# for wholesale replacing as well as merging.


ebuild_modifications = [
	InsertEbuilds(other_overlays["vmware_overlay"], select=[ "app-emulation/vmware-modules" ], skip=None, replace=True, merge=True),
	InsertEbuilds(other_overlays["pantheon_overlay"], select=[ "x11-libs/granite", "x11-libs/bamf", "x11-themes/plank-theme-pantheon", "pantheon-base/plank", "x11-wm/gala"], skip=None, replace=True, merge=True),
	InsertEbuilds(other_overlays["faustoo_overlay"], select=[ "app-office/projectlibre-bin" ], skip=None, replace=True),
	InsertEbuilds(other_overlays["foo_overlay"], select="all", skip=["sys-fs/mdev-bb", "sys-fs/mdev-like-a-boss", "media-sound/deadbeef", "media-video/handbrake"], replace=["app-shells/rssh"]),
	InsertEbuilds(funtoo_overlays["plex_overlay"], select=[ "media-tv/plex-media-server" ], skip=None, replace=True),
	InsertEbuilds(other_overlays["causes_overlay"], select=[ "media-sound/renoise", "media-sound/renoise-demo", "sys-fs/smdev", "x11-wm/dwm" ], skip=None, replace=True),
	InsertEbuilds(other_overlays["sabayon_for_gentoo"], select=["app-admin/equo", "app-admin/matter", "sys-apps/entropy", "sys-apps/entropy-server", "sys-apps/entropy-client-services","app-admin/rigo", "sys-apps/rigo-daemon", "sys-apps/magneto-core", "x11-misc/magneto-gtk", "x11-misc/magneto-gtk3", "x11-themes/numix-icon-theme", "kde-misc/magneto-kde", "app-misc/magneto-loader", "media-video/kazam" ], replace=True),
	InsertEbuilds(other_overlays["tripsix_overlay"], select=["media-sound/rakarrack"], skip=None, replace=True, merge=False),
	InsertEbuilds(other_overlays["pinsard_overlay"], select=["x11-wm/qtile"], skip=None, replace=True, merge=False),
]

ebuild_modifications += [
	InsertEbuilds(funtoo_overlays["funtoo_media"], select="all", skip=None, replace=True),
	InsertEbuilds(funtoo_overlays["ldap_overlay"], select="all", skip=None, replace=True),
]

# Steps related to eclass copying:

eclass_steps = [
		SyncDir(funtoo_overlays["deadbeef_overlay"].root,"eclass"),

]

# General tree preparation steps -- finishing touches. This is where you should put steps that require all ebuilds
# from all trees to all be inserted (like AutoGlobMask calls) as well as misc. copying of files like licenses and
# updates files. It also contains misc. tweaks like mirror fixups and Portage tree minification.

treeprep_steps = [
	SyncDir(funtoo_overlays["plex_overlay"].root,"licenses"),
]

master_steps = [
	InsertEbuilds(shards["perl"], select="all", skip=None, replace=True),
	InsertEclasses(shards["perl"], select=re.compile(".*\.eclass")),
	InsertEbuilds(shards["x11"], select="all", skip=None, replace=True),
	InsertEbuilds(shards["kde"], select="all", skip=None, replace=True),
	InsertEclasses(shards["kde"], select=re.compile(".*\.eclass")),
	InsertEbuilds(shards["gnome"], select="all", skip=None, replace=True),
	InsertEbuilds(funtoo_overlays["gnome_fixups"], select="all", skip=None, replace=True),
	InsertEbuilds(shards["core"], select="all", skip=None, replace=True),
	InsertEclasses(shards["core"], select=re.compile(".*\.eclass")),
	InsertEbuilds(funtoo_overlays["funtoo_toolchain"], select="all", skip=None, replace=True, merge=False),
	InsertEbuilds(funtoo_overlay, select="all", skip=None, replace=True),
	SyncDir(funtoo_overlay.root, "eclass"),
	SyncDir(funtoo_overlay.root,"licenses"),
	SyncDir(funtoo_overlay.root,"metadata"),
	SyncFiles(funtoo_overlay.root, {
		"COPYRIGHT.txt":"COPYRIGHT.txt",
		"LICENSE.txt":"LICENSE.txt",
		"README.rst":"README.rst",
		"header.txt":"header.txt",
	}),
]

treeprep_steps += [
	MergeUpdates(funtoo_overlay.root),
	AutoGlobMask("dev-lang/python", "python*_pre*", "funtoo-python_pre"),
	ThirdPartyMirrors(),
	ProfileDepFix(),
	Minify(),
	# Set name of repository as "gentoo". Unset masters.
	RunSed(["metadata/layout.conf"], ["s/^repo-name = .*/repo-name = gentoo/", "/^masters =/d"]),
	RunSed(["profiles/repo_name"], ["s/.*/gentoo/"]),
	GenUseLocalDesc()
]

all_steps = [ base_steps, profile_steps, ebuild_additions, ebuild_modifications, eclass_steps, master_steps, treeprep_steps ]

for step in all_steps:
	funtoo_staging_w.run(step)
funtoo_staging_w.gitCommit(message="glorious funtoo updates",branch=push)
if xmlfile:
	a=open(xmlfile,"wb")
	etree.ElementTree(xml_out).write(a, encoding='utf-8', xml_declaration=True, pretty_print=True)
	a.close()
print("merge-funtoo-staging.py completed successfully.")
sys.exit(0)

# vim: ts=4 sw=4 noet
