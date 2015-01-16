#!/usr/bin/python3

from merge_utils import *

# Progress overlay merge
if not os.path.exists("/usr/bin/svn"):
	print("svn binary not found at /usr/bin/svn. Exiting.")
	sys.exit(1)

gentoo_use_rsync = False
if gentoo_use_rsync:
	gentoo_src = RsyncTree("gentoo")
else:
	gentoo_src = CvsTree("gentoo-x86",":pserver:anonymous@anoncvs.gentoo.org:/var/cvsroot")
	gentoo_glsa = CvsTree("gentoo-glsa",":pserver:anonymous@anoncvs.gentoo.org:/var/cvsroot", path="gentoo/xml/htdocs/security")
funtoo_overlay = GitTree("funtoo-overlay", branch, "repos@git.funtoo.org:funtoo-overlay.git", pull=True)
foo_overlay = GitTree("foo-overlay", "master", "https://github.com/slashbeast/foo-overlay.git", pull=True)
bar_overlay = GitTree("bar-overlay", "master", "git://github.com/adessemond/bar-overlay.git", pull=True)
funtoo_media = GitTree("funtoo-media", "master", "repos@git.funtoo.org:funtoo-media.git", pull=True)
causes_overlay = GitTree("causes","master", "https://github.com/causes-/causelay", pull=True)
bliss_overlay = GitTree("bliss-overlay", "master", "https://github.com/fearedbliss/bliss-overlay.git", pull=True)
squeezebox_overlay = GitTree("squeezebox", "master", "git://git.overlays.gentoo.org/user/squeezebox.git", pull=True)
progress_overlay = SvnTree("progress", "https://gentoo-progress.googlecode.com/svn/overlays/progress")
plex_overlay = GitTree("funtoo-plex", "master", "https://github.com/Ghent/funtoo-plex.git", pull=True)
sabayon_for_gentoo = GitTree("sabayon-for-gentoo", "master", "git://github.com/Sabayon/for-gentoo.git", pull=True)
#funtoo_gnome_overlay = GitTree("funtoo-gnome", "experimental" if experimental else "master", "repos@git.funtoo.org:funtoo-gnome-overlay.git", pull=True)
funtoo_gnome_overlay = GitTree("funtoo-gnome", "master", "repos@git.funtoo.org:funtoo-gnome-overlay.git", pull=True)
funtoo_toolchain_overlay = GitTree("funtoo-toolchain", "master", "repos@git.funtoo.org:funtoo-toolchain-overlay.git", pull=True)
mysql_overlay = GitTree("funtoo-mysql", "master", "repos@git.funtoo.org:funtoo-mysql.git", pull=True)
ldap_overlay = GitTree("funtoo-ldap", "master", "repos@git.funtoo.org:funtoo-ldap-overlay.git", pull=True)
funtoo_deadbeef = GitTree("funtoo-deadbeef", "master", "https://github.com/damex/funtoo-deadbeef.git", pull=True)
funtoo_redhat = GitTree("funtoo-redhat", "master", "https://github.com/damex/funtoo-redhat.git", pull=True)
funtoo_wmfs = GitTree("funtoo-wmfs", "master", "https://github.com/damex/funtoo-wmfs.git", pull=True)
faustoo_overlay = GitTree("faustoo", "master", "https://github.com/fmoro/faustoo.git", pull=True)
sera_overlay = GitTree("sera", "master", "git://git.overlays.gentoo.org/dev/sera.git", pull=True)
vmware_overlay = GitTree("vmware", "master", "git://git.overlays.gentoo.org/proj/vmware.git", pull=True)

#xorg treelet:
"""
xorg_treelet = GitWriteTree(

.treelet_update(gentoo_src, select=[
	"x11-base/*", 
	"x11-drivers/*", 
	"x11-wm/twm", 
	"x11-terms/xterm"
])
"""

# base_steps define the initial steps that prepare our destination tree for writing. Checking out the correct
# branch, copying almost the full entirety of Gentoo's portage tree to our destination tree, and copying over
# funtoo overlay licenses, metadata, and also copying over GLSA's.

base_steps = [
	GitCheckout("funtoo.org"),
	SyncFromTree(gentoo_src, exclude=["/metadata/cache/**", "ChangeLog", "dev-util/metro"]),
	SyncDir(funtoo_overlay.root,"licenses"),
	SyncDir(funtoo_overlay.root,"metadata"),
		# Only include 2012 and up GLSA's:
	SyncDir(gentoo_glsa.root, "en/glsa", "metadata/glsa", exclude=["glsa-200*.xml","glsa-2010*.xml", "glsa-2011*.xml"]) if not gentoo_use_rsync else None,
		SyncFiles(funtoo_overlay.root, {
		"COPYRIGHT.txt":"COPYRIGHT.txt",
		"LICENSE.txt":"LICENSE.txt",
		"README.rst":"README.rst"
	}),
]

# Steps related to generating system profiles. These can be quite order-dependent and should be handled carefully.
# Generally, the funtoo_overlay sync should be first, then the gentoo_src SyncFiles, which overwrites some stub
# files in the funtoo overlay.

profile_steps = [
	SyncDir(funtoo_overlay.root, "profiles", "profiles", exclude=["categories", "updates"]),
	SyncFiles(gentoo_src.root, {
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
	SyncFiles(funtoo_deadbeef.root, {
		"profiles/package.mask":"profiles/package.mask/deadbeef-mask"
	}),
	SyncFiles(funtoo_wmfs.root, {
		"profiles/package.mask":"profiles/package.mask/wmfs-mask"
	}),
	SyncDir(progress_overlay.root, "profiles/unpack_dependencies"),
	SyncFiles(progress_overlay.root, {
		"profiles/package.mask":"profiles/package.mask/progress",
		"profiles/use.aliases":"profiles/use.aliases/progress",
		"profiles/use.mask":"profiles/use.mask/progress"
	}),
	SyncFiles(funtoo_gnome_overlay.root, {
		"profiles/package.mask":"profiles/package.mask/funtoo-gnome"
	}),
	SyncFiles(funtoo_toolchain_overlay.root, {
		"profiles/package.mask/funtoo-toolchain":"profiles/funtoo/1.0/linux-gnu/build/current/package.mask/funtoo-toolchain",
	}),
	SyncFiles(funtoo_toolchain_overlay.root, {
		"profiles/package.mask/funtoo-toolchain":"profiles/funtoo/1.0/linux-gnu/build/stable/package.mask/funtoo-toolchain",
		"profiles/package.mask/funtoo-toolchain-experimental":"profiles/funtoo/1.0/linux-gnu/build/experimental/package.mask/funtoo-toolchain",
	}),
]

# Steps related to copying ebuilds. Note that order can make a difference here when multiple overlays are
# providing identical catpkgs.

# Ebuild additions -- these are less-risky changes because ebuilds are only added, and not replaced.

ebuild_additions = [
	InsertEbuilds(bar_overlay, select="all", skip=["app-emulation/qemu"], replace=False),
	InsertEbuilds(bliss_overlay, select="all", skip=["net-p2p/bittorrent-sync"], replace=False),
	InsertEbuilds(squeezebox_overlay, select="all", skip=None, replace=False),
	InsertEbuilds(funtoo_deadbeef, select="all", skip=None, replace=False),
	InsertEbuilds(funtoo_redhat, select="all", skip=None, replace=False),
	InsertEbuilds(funtoo_wmfs, select="all", skip=None, replace=False),
]

# Ebuild modifications -- these changes need to be treated more carefully as ordering can be important
# for wholesale replacing as well as merging.


ebuild_modifications = [
	InsertEbuilds(vmware_overlay, select=[ "app-emulation/vmware-modules" ], skip=None, replace=True, merge=True),
	InsertEbuilds(sera_overlay, select="all", skip=None, replace=True, merge=True),
	InsertEbuilds(faustoo_overlay, select=[ "app-office/projectlibre-bin" ], skip=None, replace=True),
	InsertEbuilds(foo_overlay, select="all", skip=["sys-fs/mdev-bb", "sys-fs/mdev-like-a-boss", "media-sound/deadbeef", "media-video/handbrake"], replace=["app-shells/rssh","net-misc/unison"]),
	InsertEbuilds(plex_overlay, select = [ "media-tv/plex-media-server" ], skip=None, replace=True),
	InsertEbuilds(causes_overlay, select=[ "media-sound/renoise", "media-sound/renoise-demo", "sys-fs/smdev", "x11-wm/dwm" ], skip=None, replace=True),
	InsertEbuilds(sabayon_for_gentoo, select=["sci-geosciences/grass", "app-admin/equo", "app-admin/matter", "sys-apps/entropy", "sys-apps/entropy-server", "sys-apps/entropy-client-services","app-admin/rigo", "sys-apps/rigo-daemon", "sys-apps/magneto-core", "x11-misc/magneto-gtk", "x11-misc/magneto-gtk3", "kde-misc/magneto-kde", "app-misc/magneto-loader"], replace=True),
	InsertEbuilds(progress_overlay, select="all", skip=None, replace=True, merge=False),
	InsertEbuilds(funtoo_gnome_overlay, select="all", skip=None, replace=True, merge=["dev-python/pyatspi", "dev-python/pygobject", "dev-util/gdbus-codegen", "x11-libs/vte"]),
	InsertEbuilds(mysql_overlay, select="all", skip=None, replace=True),
	InsertEbuilds(funtoo_media, select="all", skip=None, replace=True),
	InsertEbuilds(funtoo_overlay, select="all", skip=None, replace=True),
	InsertEbuilds(funtoo_toolchain_overlay, select="all", skip=None, replace=True, merge=False),
	InsertEbuilds(ldap_overlay, select="all", skip=None, replace=True),
]

# Steps related to eclass copying:

eclass_steps = [
	SyncDir(funtoo_deadbeef.root,"eclass"),
	SyncDir(funtoo_gnome_overlay.root,"eclass"),
	SyncDir(progress_overlay.root, "eclass"),
	SyncDir(mysql_overlay.root, "eclass"),
	SyncDir(funtoo_overlay.root, "eclass"),
]

# General tree preparation steps -- finishing touches. This is where you should put steps that require all ebuilds
# from all trees to all be inserted (like AutoGlobMask calls) as well as misc. copying of files like licenses and
# updates files. It also contains misc. tweaks like mirror fixups and Portage tree minification.

treeprep_steps = [	
	SyncDir(plex_overlay.root,"licenses"),
	MergeUpdates(progress_overlay.root),
	MergeUpdates(funtoo_overlay.root),
	AutoGlobMask("dev-lang/python", "python*_pre*", "funtoo-python"),
	ThirdPartyMirrors(),
	ProfileDepFix(),
	Minify(),
	# Set name of repository as "gentoo". Unset masters.
	RunSed(["metadata/layout.conf"], ["s/^repo-name = .*/repo-name = gentoo/", "/^masters =/d"]),
	RunSed(["profiles/repo_name"], ["s/.*/gentoo/"]),
	# Set _PYTHON_GLOBALLY_NONDEFAULT_ABIS="3.[4-9]" variable for single-Python-ABI packages.
	# This value should be kept in synchronization with PYTHON_ABIS variable set in profiles/funtoo/1.0/linux-gnu/make.defaults.
	# This value should match Python ABIs newer than Python ABIs listed in PYTHON_ABIS variable.
	RunSed(["eclass/python.eclass"], [r"s/^\(_PYTHON_GLOBALLY_NONDEFAULT_ABIS\)=.*/\1=\"3.[4-9]\"/"]),
	GenCache(),
	GenUseLocalDesc()
]

# all_steps lists all of the groups of steps, in order, that will be executed to generate our Portage tree:

all_steps = [ base_steps, profile_steps, ebuild_additions, ebuild_modifications, eclass_steps, treeprep_steps ]

# These steps are deprecated and are kept here for reference only:
#
# deprecated_steps = [
#	ApplyPatchSeries("%s/funtoo/patches" % funtoo_overlay.root ),
# ]

xml_out = etree.Element("packages")
# specify a git tree that we will do all our stuff in. Initialize (create from scratch) if it doesn't exist:
initialize=False
if args.init:
	initialize="funtoo.org"
	push = False
elif not os.path.exists(dest):
	print("Destination Portage tree %s does not exist. Use --init if you want to create a new repo." % dest)
	sys.exit(1)
if args.nopush:
	push = False
else:
	push = "funtoo.org"

work = GitTree(os.path.basename(dest), branch="funtoo.org", root=dest, xml_out=xml_out, initialize=initialize)
# Run various groups of steps to prepare our Portage tree. Ordering is important:
for step in all_steps:
    work.run(step)
work.gitCommit(message="glorious funtoo updates",branch=push)

if experimental:
	a=open("/home/ports/public_html/experimental-packages.xml","wb")
else:
	a=open("/home/ports/public_html/packages.xml","wb")
etree.ElementTree(xml_out).write(a, encoding='utf-8', xml_declaration=True, pretty_print=True)
a.close()
