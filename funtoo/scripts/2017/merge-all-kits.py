#!/usr/bin/python3

import os
from merge_utils import *

# KIT DESIGN AND DEVELOPER DOCS

# The maintainable model for kits is to have several source repositories that contain most of our source ebuilds/
# catpkgs, which are identified by SHA1 to point to a specific snapshot. Then, we combine that with a Funtoo 'kit-fixups'
# repository that contains only our forked ebuilds. Then this script, merge-all-kits.py, is used to automatically
# generate the kits. We don't commit directly to kits themselves -- this script automatically generates commits with
# updated ebuilds. 

# A kit is generated from:

# 1. a collection of repositories and SHA1 commit to specify a snapshot of each repository to serve as a source for catpkgs,
#    eclasses, licenses. It is also possible to specify a branch name instead of SHA1 (typically 'master') although this
#    shouldn't ever be done for 'prime' branches of kits.

# 1. a selection of catpkgs (ebuilds) that are selected from source repositories. Each kit has a package-set file located 
#    in ../package-sets/*-kit relative to this file which contains patterns of catpkgs to select from each source 
#    repository and copy into the kit when regenerating it.

# 3. a collection of fix-ups (from the kit-fixups repository) that can be used to replace catpkgs in various kits globally,
#    or in a specific branch of a kit. There is also an option to provide eclasses that get copied globally to each kit,
#    to a particular kit, or to a branch of a particular kit. This is the where we fork ebuilds to fix specific issues.

# Below, the kits and branches should be defined in a way that includes all this information. It is also possible to
# have a kit that simply is a collection of ebuilds but tracks the latest gentoo-staging. It may or may not have
# additional fix-ups.

# When setting up a kit repository, the 'master' branch may used to store an 'unfrozen' kit that just tracks upstream
# Gentoo. Kits are not required to have a master branch -- we only create one if the kit is designed to offer unfrozen
# ebuilds to Funtoo users.	Examples below are: science-kit, games-kit, text-kit, net-kit. These track gentoo.

# If we have a frozen enterprise branch that we are backporting security fixes to only, we want this to be an
# 'x.y-prime' branch. This branch's overlays' source SHA1s are not supposed to change and we will just augment it with
# fix-ups as needed.

# As kits are maintained, the following things may change:
#
# 1. The package-set files may change. This can result in different packages being selected for the kit the next time it
#	 is regenerated by this script. We can add mising packages, decide to move packages to other kits, etc. This script
#	 takes care of ensuring that all necessary eclasses and licenses are included when the kit is regenerated.
#
# 2. The fix-ups may change. This allows us to choose to 'fork' various ebuilds that we may need to fix, while keeping
#	 our changes separate from the source packages. We can also choose to unfork packages.
#
# 3. Kits can be added or removed.
#
# 4. Kit branches can be created, or alternatively deprecated. We need a system for gracefully deprecating a kit that does
#	 not involve deleting the branch. A user may decide to continue using the branch even if it has been deprecated.
#
# 5. Kits can be tagged by Funtoo as being mandatory or optional. Typically, most kits will be mandatory but some effort
#	 will be made as we progress to make things like the games-kit or the science-kit optional.
#
# HOW KITS ARE GENERATED

# Currently, kits are regenerated in a particluar order, such as: "first, core-kit, then security-kit, then perl-kit",
# etc. This script keeps a running list of catpkgs that are inserted into each kit. Once a catpkg is inserted into a
# kit, it is not available to be inserted into successive kits. This design is intended to prevent multiple copies of
# catpkgs existing in multiple kits in parallel that are designed to work together as a set. At the end of kit
# generation, this master list of inserted catpkgs is used to prune the 'nokit' repository of catpkgs, so that 'nokit'
# contains the set of all ebuilds that were not inserted into kits.

# Below, you will see how the sources for kits are defined.

# 1. OVERLAYS - lists sources for catpkgs, along with properties which can include "select" - a list of catpkgs to
# include.  When "select" is specified, only these catpkgs will be available for selection by the package-set rules. .
# If no "select" is specified, then by default all available catpkgs could be included, if they match patterns, etc. in
# package-sets. Note that we do not specify branch or SHA1 here. This may vary based on kit, so it's specified elsewhere
# (see KIT SOURCES, below.)

overlays = {
	# use gentoo-staging-2017 dirname to avoid conflicts with ports-2012 generation
	"gentoo-staging" : { "type" : GitTree, "url" : "repos@git.funtoo.org:ports/gentoo-staging.git", "dirname" : "gentoo-staging-2017" },
	"faustoo" : { "type" : GitTree, "url" : "https://github.com/fmoro/faustoo.git", "eclasses" : [
		"waf",
		"googlecode"
	] }, # add select ebuilds here?
	"fusion809" : { "type" : GitTree, "url" : "https://github.com/fusion809/fusion809-overlay.git", "select" : [
			"app-editors/atom-bin", 
			"app-editors/notepadqq", 
			"app-editors/bluefish", 
			"app-editors/textadept", 
			"app-editors/scite", 
			"app-editors/gvim", 
			"app-editors/vim", 
			"app-editors/vim-core", 
			"app-editors/visual-studio-code", 
			"app-editors/sublime-text"
		]
	}, # FL-3633, FL-3663, FL-3776
	"plex" : { "type" : GitTree, "url" : "https://github.com/Ghent/funtoo-plex.git", "select" : [
			"media-tv/plex-media-server",
		],
	},
	# Ryan Harris glassfish overlay. FL-3985:
	"rh1" : { "type" : GitTree, "url" : "https://github.com/x48rph/glassfish.git", "select" : [
			"www-servers/glassfish-bin",
		],
	},
	# damex's deadbeef (music player like foobar2000) overlay
	"deadbeef" : { "type" : GitTree, "url" : "https://github.com/damex/deadbeef-overlay.git", "copyfiles" : {
			"profiles/package.mask": "profiles/package.mask/deadbeef.mask"
		},
	},
	# damex's wmfs (window manager from scratch) overlay
	"wmfs" : { "type" : GitTree, "url" : "https://github.com/damex/wmfs-overlay.git", "copyfiles" : {
			"profiles/package.mask": "profiles/package.mask/wmfs.mask" 
		},
	},
	"flora" : { "type" : GitTree, "url" : "https://github.com/funtoo/flora.git", "copyfiles" : {
			"licenses/renoise-EULA": "licenses/renoise-EULA"
		},
	},
}

# SUPPLEMENTAL REPOSITORIES: These are overlays that we are using but are not in KIT SOURCES. funtoo_overlay is something
# we are using only for profiles and other misc. things and may get phased out in the future:

funtoo_overlay = GitTree("funtoo-overlay", "master", "repos@git.funtoo.org:funtoo-overlay.git")
fixup_repo = GitTree("kit-fixups", "master", "repos@git.funtoo.org:kits/kit-fixups.git")

meta_repo = GitTree("meta-repo", "master", "repos@git.funtoo.org:meta-repo.git", root="/var/git/dest-trees/meta-repo")

# 2. KIT SOURCES - kit sources are a combination of overlays, arranged in a python list [ ]. A KIT SOURCE serves as a
# unified collection of source catpkgs for a particular kit. Each kit can have one KIT SOURCE. KIT SOURCEs MAY be
# shared among kits to avoid duplication and to help organization. Note that this is where we specify branch or SHA1
# for each overlay.

# Each kit source can be used as a source of catpkgs for a kit. Order is important -- package-set rules are applied in
# the same order that the overlay appears in the kit_source_defs list -- so for "gentoo_current", package-set rules will
# be applied to gentoo-staging first, then flora, then faustoo, then fusion809. Once a particular catpkg matches and is
# copied into a dest-kit, a matching capkg in a later overlay, if one exists, will be ignored.

# It is important to note that we support two kinds of kit sources -- the first is the gentoo-staging master repository
# which contains a master set of eclasses and contains everything it needs for all the catpkgs it contains. The second
# kind of repository we support is an overlay that is designed to be used with the gentoo-staging overlay, so it may
# need some catpkgs (as dependencies) or eclasses from gentoo-staging. The gentoo-staging repository should always
# appear as the first item in kit_source_defs, with the overlays appearing after.

kit_source_defs = {
	"gentoo_current" : [
		{ "repo" : "gentoo-staging" },
		{ "repo" : "flora" },
		{ "repo" : "faustoo" },
		{ "repo" : "fusion809" },
		{ "repo" : "rh1" }
	],
	"gentoo_prime" : [
		{ "repo" : "gentoo-staging", "src_sha1" : '06a1fd99a3ce1dd33724e11ae9f81c5d0364985e', 'date' : '21 Apr 2017'},
		{ "repo" : "flora", },
		{ "repo" : "faustoo", "src_sha1" : "58c805ec0df34cfc699e6555bf317590ff9dee15", },
		{ "repo" : "fusion809", "src_sha1" : "8322bcd79d47ef81f7417c324a1a2b4772020985", "options" : { "merge" : True }},
		{ "repo" : "rh1", },
	],
	"gentoo_prime_xorg" : [
		{ "repo" : "gentoo-staging", 'src_sha1' : 'a56abf6b7026dae27f9ca30ed4c564a16ca82685', 'date' : '18 Nov 2016' }
	],
	"gentoo_prime_gnome" : [
		{ "repo" : "gentoo-staging", 'src_sha1' : '44677858bd088805aa59fd56610ea4fb703a2fcd', 'date' : '18 Sep 2016' }
	],
	"gentoo_prime_media" : [
		{ "repo" : "gentoo-staging", 'src_sha1' : '355a7986f9f7c86d1617de98d6bf11906729f108', 'date' : '25 Feb 2017' }
	],
	"gentoo_prime_perl" : [
		{ "repo" : "gentoo-staging", 'src_sha1' : 'fc74d3206fa20caa19b7703aa051ff6de95d5588', 'date' : '11 Jan 2017' }
	]
}

# 2. KIT GROUPS - this is where kits are actually defined. They are organized by GROUP: 'prime', 'current', or 'shared'.
# 'prime' kits are production-quality kits. Current kits are bleeding-edge kits. 'shared' kits are used by both 'prime'
# and 'current' -- they can have some "prime" kits as well as some "current" kits depending on what we want to stabilize.
# Note that we specify a 'source' which points to a name of a kit_source to use as a source of ebuilds. A kit is defined
# by a GROUP such as 'prime', a NAME, such as 'core-kit', a BRANCH, such as '1.0-prime', and a source (kit source) such
# as 'gentoo_prime'.

kit_groups = {
	'prime' : [
		{ 'name' : 'core-kit', 'branch' : '1.0-prime', 'source': 'gentoo_prime' },
		{ 'name' : 'core-hw-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'security-kit', 'branch' : '1.0-prime', 'source': 'gentoo_prime' },
		{ 'name' : 'xorg-kit', 'branch' : '1.17-prime', 'source': 'gentoo_prime_xorg' },
		{ 'name' : 'gnome-kit', 'branch' : '3.20-prime', 'source': 'gentoo_prime_gnome' },
		{ 'name' : 'media-kit', 'branch' : '1.0-prime', 'source': 'gentoo_prime_media' },
		{ 'name' : 'perl-kit', 'branch' : '5.24-prime', 'source': 'gentoo_prime_perl' },
		{ 'name' : 'python-kit', 'branch' : '3.4-prime', 'source': 'gentoo_prime' },
		{ 'name' : 'php-kit', 'branch' : '7.1.3-prime', 'source': 'gentoo_prime' },
	],
	'shared' : [
		{ 'name' : 'java-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'dev-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'kde-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'desktop-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'editors-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'net-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'text-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'science-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'games-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'nokit', 'branch' : 'master', 'source': 'gentoo_current' }
	],
	'current' : [
		{ 'name' : 'core-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'security-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'xorg-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'gnome-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'media-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'perl-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'python-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'php-kit', 'branch' : 'master', 'source': 'gentoo_current' },
	],
}


# It has already been explained how when we apply package-set rules, we process the kit_source repositories in order and
# after we find a catpkg that matches, any matches in successive repositories for catpkgs that we have already copied
# over to the destination kit are *ignored*. This is implemented using a dictionary called "kitted_catpkgs".  Once a
# catpkg is inserted into a kit, it's no longer 'available' to be inserted into successive kits, to avoid duplicates.

kit_order = [ 'prime', 'shared', None, 'current' ]

# We want to reset 'kitted_catpkgs' at certain points. The 'kit_order' variable below is used to control this, and we
# normally don't need to touch it. 'kitted_order' above tells the code to generate 'prime', then 'shared' (without
# resetting kitted_catpkgs to empty), then the None tells the code to reset kitted_catpkgs, so when 'current' kits are
# generated, they can include from all possible catpkgs. This is done because prime+shared is designed to be our
# primary enterprise-set of Funtoo kits. current+shared is also supported as a more bleeding edge option.

# 3. KIT PREP STEPS. To rebuild kits from scratch, we need to perform some initial actions to initialize an empty git
# repository, as well as some final actions. In the kit_steps dictionary below, indexed by kit, 'pre' dict lists the
# initial actions, and 'post' lists the final actions for the kit. There is also a special top-level key called
# 'regular-kits'. These actions are appended to any kit that is not core-kit or nokit. In addition to 'pre' and 'post'
# steps, there is also a 'copy' step that is not currently used (but is supported by getKitPrepSteps()).

def getKitPrepSteps(repos, kit_dict, gentoo_staging):

	global fixup_repo

	kit_steps = {
		'core-kit' : { 'pre' : [
				GenerateRepoMetadata("core-kit", aliases=["gentoo"], priority=1000),
				# core-kit has special logic for eclasses -- we want all of them, so that third-party overlays can reference the full set.
				# All other kits use alternate logic (not in kit_steps) to only grab the eclasses they actually use.
				SyncDir(gentoo_staging.root, "eclass"),
							],
			'post' : [
				# We copy files into funtoo's profile structure as post-steps because we rely on kit-fixups step to get the initial structure into place
				# We also have special code that switches to the latest commit of gentoo_staging for this part, so we get the latest masks, etc. from 
				# gentoo.
				CopyAndRename("profiles/funtoo/1.0/linux-gnu/arch/x86-64bit/subarch", "profiles/funtoo/1.0/linux-gnu/arch/pure64/subarch", lambda x: os.path.basename(x) + "-pure64"),
				# news items are not included here anymore
				SyncDir(gentoo_staging.root, "profiles/base"),
				SyncDir(gentoo_staging.root, "profiles/arch/base"),
				SyncDir(gentoo_staging.root, "profiles/updates"),
				SyncDir(gentoo_staging.root, "metadata", exclude=["cache","md5-cache","layout.conf"]),
				SyncFiles(gentoo_staging.root, {
					"profiles/package.mask":"profiles/package.mask/00-gentoo",
					"profiles/arch/amd64/package.use.mask":"profiles/funtoo/1.0/linux-gnu/arch/x86-64bit/package.use.mask/01-gentoo",
					"profiles/arch/amd64/use.mask":"profiles/funtoo/1.0/linux-gnu/arch/x86-64bit/use.mask/01-gentoo",
					"profiles/arch/x86/package.use.mask":"profiles/funtoo/1.0/linux-gnu/arch/x86-32bit/package.use.mask/01-gentoo",
					"profiles/arch/x86/use.mask":"profiles/funtoo/1.0/linux-gnu/arch/x86-32bit/use.mask/01-gentoo",
					"profiles/default/linux/package.use.mask":"profiles/funtoo/1.0/linux-gnu/package.use.mask/01-gentoo",
					"profiles/default/linux/use.mask":"profiles/funtoo/1.0/linux-gnu/use.mask/01-gentoo",
					"profiles/arch/amd64/no-multilib/package.use.mask":"profiles/funtoo/1.0/linux-gnu/arch/pure64/package.use.mask/01-gentoo",
					"profiles/arch/amd64/no-multilib/package.mask":"profiles/funtoo/1.0/linux-gnu/arch/pure64/package.mask/01-gentoo",
					"profiles/arch/amd64/no-multilib/use.mask":"profiles/funtoo/1.0/linux-gnu/arch/pure64/use.mask/01-gentoo"
				}),
				SyncFiles(gentoo_staging.root, {
					"profiles/info_pkgs" : "profiles/info_pkgs",
					"profiles/thirdpartymirrors" : "profiles/thirdpartymirrors",
					"profiles/license_groups" : "profiles/license_groups",
					"profiles/use.desc" : "profiles/use.desc",
				}),
				# add funtoo stuff to thirdpartymirrors
				ThirdPartyMirrors(),
				RunSed(["profiles/base/make.defaults"], ["/^PYTHON_TARGETS=/d", "/^PYTHON_SINGLE_TARGET=/d"]),
			]
		},
		# masters of core-kit for regular kits and nokit ensure that masking settings set in core-kit for catpkgs in other kits are applied
		# to the other kits. Without this, mask settings in core-kit apply to core-kit only.
		'regular-kits' : { 'pre' : [
				GenerateRepoMetadata(kit_dict['name'], masters=[ "core-kit" ], priority=500),
			]
		},
		'all-kits' : { 'pre' : [
				SyncFiles(fixup_repo.root, {
						"COPYRIGHT.txt":"COPYRIGHT.txt",
						"LICENSE.txt":"LICENSE.txt",
					}),
			]
		},
		'nokit' : { 'pre' : [
				GenerateRepoMetadata("nokit", masters=[ "core-kit" ], priority=-2000),
			]
		}
	}

	out_pre_steps = []
	out_copy_steps = []
	out_post_steps = []

	kd = kit_dict['name']
	if kd in kit_steps:
		if 'pre' in kit_steps[kd]:
			out_pre_steps += kit_steps[kd]['pre']
		if 'post' in kit_steps[kd]:
			out_post_steps += kit_steps[kd]['post']
		if 'copy' in kit_steps[kd]:
			out_copy_steps += kit_steps[kd]['copy']

	# a 'regular kit' is not core-kit or nokit -- if we have pre or post steps for them, append these steps:
	if kit_dict['name'] not in [ 'core-kit', 'nokit' ] and 'regular-kits' in kit_steps:
		if 'pre' in kit_steps['regular-kits']:
			out_pre_steps += kit_steps['regular-kits']['pre']
		if 'post' in kit_steps['regular-kits']:
			out_post_steps += kit_steps['regular-kits']['post']

	if 'all-kits' in kit_steps:
		if 'pre' in kit_steps['all-kits']:
			out_pre_steps += kit_steps['all-kits']['pre']
		if 'post' in kit_steps['all-kits']:
			out_post_steps += kit_steps['all-kits']['post']

	return ( out_pre_steps, out_copy_steps, out_post_steps )

# GET KIT SOURCE INSTANCE. This function returns a list of GitTree objects for each of repositories specified for
# a particular kit's kit_source, in the order that they should be processed (in the order they are defined in
# kit_source_defs, in other words.)

def getKitSourceInstance(kit_dict):

	global kit_source_defs
	
	source_name = kit_dict['source']

	repos = []

	source_defs = kit_source_defs[source_name]

	for source_def in source_defs:

		repo_name = source_def['repo']
		repo_branch = source_def['src_branch'] if "src_branch" in source_def else "master"
		repo_sha1 = source_def["src_sha1"] if "src_sha1" in source_def else None
		repo_obj = overlays[repo_name]["type"]
		repo_url = overlays[repo_name]["url"]
		if "dirname" in overlays[repo_name]:
			path = overlays[repo_name]["dirname"]
		else:
			path = repo_name
		print("INITIALIZING Git Repo", repo_url, repo_branch, repo_sha1)
		repo = repo_obj(repo_name, url=repo_url, root="/var/git/source-trees/%s" % path, branch=repo_branch, commit_sha1=repo_sha1)
		print("DEBUG: ", repo.currentLocalBranch, headSHA1(repo.root))

		if "options" in source_def:
			sro = source_def["options"].copy()
		else:
			sro = {}
		if "select" in overlays[repo_name]:
			sro["select"] = overlays[repo_name]["select"]

		repos.append( { "name" : repo_name, "repo" : repo, "options" : sro } )

	return repos

# UPDATE KIT. This function does the heavy lifting of taking a kit specification included in a kit_dict, and
# regenerating it. The kitted_catpkgs argument is a dictionary which is also written to and used to keep track of
# catpkgs copied between runs of updateKit.

def updateKit(kit_dict, cpm_logger, create=False, push=False):

	# get set of source repos used to grab catpkgs from:

	repos = kit_dict["repo_obj"] = getKitSourceInstance(kit_dict)

	# get a handy variable reference to gentoo_staging:
	gentoo_staging = None
	for x in repos:
		if x["name"] == "gentoo-staging":
			gentoo_staging = x["repo"]
			break

	if gentoo_staging == None:
		print("Couldn't find source gentoo staging repo")
	elif gentoo_staging.name != "gentoo-staging":
		print("Gentoo staging mismatch -- name is %s" % gentoo_staging["name"])

	# we should now be OK to use the repo and the local branch:
	kit_dict['tree'] = tree = GitTree(kit_dict['name'], kit_dict['branch'], "repos@git.funtoo.org:kits/%s.git" % kit_dict['name'], create=create, root="/var/git/dest-trees/%s" % kit_dict['name'], pull=True)
	
	# Phase 1: prep the kit
	pre_steps = [
		GitCheckout(kit_dict['branch']),
		CleanTree()
	]
	
	prep_steps = getKitPrepSteps(repos, kit_dict, gentoo_staging)
	pre_steps += prep_steps[0]
	copy_steps = prep_steps[1]
	post_steps = prep_steps[2]

	tree.run(pre_steps)

	# Phase 2: copy core set of ebuilds

	# Here we generate our main set of ebuild copy steps, based on the contents of the package-set file for the kit. The logic works as
	# follows. We apply our package-set logic to each repo in succession. If copy ebuilds were actually copied (we detect this by
	# looking for changed catpkg count in our dest_kit,) then we also run additional steps: "copyfiles" and "eclasses". "copyfiles"
	# specifies files like masks to copy over to the dest_kit, and "eclasses" specifies eclasses from the overlay that we need to
	# copy over to the dest_kit. We don't need to specify eclasses that we need from gentoo_staging -- these are automatically detected
	# and copied, but if there are any special eclasses from the overlay then we want to copy these over initially.

	copycount = cpm_logger.copycount
	for repo_dict in repos:
		steps = []
		if kit_dict["name"] == "nokit":
			# grab all ebuilds to put in nokit
			steps += [ InsertEbuilds(repo_dict["repo"], select="all", skip=None, replace=True, cpm_logger=cpm_logger) ]
		else:
			steps += generateShardSteps(kit_dict['name'], repo_dict["repo"], tree, gentoo_staging, pkgdir=funtoo_overlay.root+"/funtoo/scripts", insert_kwargs=repo_dict["options"], cpm_logger=cpm_logger)
		tree.run(steps)
		if copycount != cpm_logger.copycount:
			# this means some catpkgs were installed from the repo we are currently processing. This means we also want to execute
			# 'copyfiles' and 'eclasses' copy logic:
			
			ov = overlays[repo_dict["name"]]

			if "copyfiles" in ov and len(ov["copyfiles"]):
				# since we copied over some ebuilds, we also want to make sure we copy over things like masks, etc:
				steps += [ SyncFiles(repo_dict["repo"].root, ov["copyfiles"]) ]
			if "eclasses" in ov:
				# we have eclasses to copy over, too:
				ec_files = {}
				for eclass in ov["eclasses"]:
					ecf = "/eclass/" + eclass + ".eclass"
					ec_files[ecf] = ecf
				steps += [ SyncFiles(repo_dict["repo"].root, ec_files) ]
		copycount = cpm_logger.copycount

	# Phase 3: copy eclasses, licenses, profile info, and ebuild/eclass fixups from the kit-fixups repository. 

	# First, we are going to process the kit-fixups repository and look for ebuilds and eclasses to replace. Eclasses can be
	# overridden by using the following paths inside kit-fixups:

	# kit-fixups/eclass <--------------------- global eclasses, get installed to all kits unconditionally (overrides those above)
	# kit-fixups/<kit>/global/eclass <-------- global eclasses for a particular kit, goes in all branches (overrides those above)
	# kit-fixups/<kit>/global/profiles <------ global profile info for a particular kit, goes in all branches (overrides those above)
	# kit-fixups/<kit>/<branch>/eclass <------ eclasses to install in just a specific branch of a specific kit (overrides those above)
	# kit-fixups/<kit>/<branch>/profiles <---- profile info to install in just a specific branch of a specific kit (overrides those above)

	# Note that profile repo_name and categories files are excluded from any copying.

	# Ebuilds can be installed to kits by putting them in the following location(s):

	# kit-fixups/<kit>/global/cat/pkg <------- install cat/pkg into all branches of a particular kit
	# kit-fixups/<kit>/<branch>/cat/pkg <----- install cat/pkg into a particular branch of a kit

	# Remember that at this point, we may be missing a lot of eclasses and licenses from Gentoo. We will then perform a final sweep
	# of all catpkgs in the dest_kit and auto-detect missing eclasses from Gentoo and copy them to our dest_kit. Remember that if you
	# need a custom eclass from a third-party overlay, you will need to specify it in the overlay's overlays["ov_name"]["eclasses"]
	# list. Or alternatively you can copy the eclasses you need to kit-fixups and maintain them there :)

	steps = []

	# Here is the core logic that copies all the fix-ups from kit-fixups (eclasses and ebuilds) into place:

	if os.path.exists(fixup_repo.root + "/eclass"):
		steps += [ InsertEclasses(fixup_repo, select="all", skip=None) ]
	for fixup_dir in [ "global", kit_dict["branch"] ]:
		fixup_path = kit_dict['name'] + "/" + fixup_dir
		if os.path.exists(fixup_repo.root + "/" + fixup_path):
			if os.path.exists(fixup_repo.root + "/" + fixup_path + "/eclass"):
				steps += [
					InsertFilesFromSubdir(fixup_repo, "eclass", ".eclass", select="all", skip=None, src_offset=fixup_path)
				]
			if os.path.exists(fixup_repo.root + "/" + fixup_path + "/licenses"):
				steps += [
					InsertFilesFromSubdir(fixup_repo, "licenses", None, select="all", skip=None, src_offset=fixup_path)
				]
			if os.path.exists(fixup_repo.root + "/" + fixup_path + "/profiles"):
				steps += [
					InsertFilesFromSubdir(fixup_repo, "profiles", None, select="all", skip=["repo_name", "categories"] , src_offset=fixup_path)
				]
			# copy appropriate kit readme into place:
			readme_path = fixup_path + "/README.rst"
			if os.path.exists(fixup_repo.root + "/" + readme_path ):
				steps += [
					SyncFiles(fixup_repo.root, {
						readme_path : "README.rst"
					})
				]
			steps += [
				# here we log catpkgs to the CatPkgMatchLogger, but cpm_ignore=True tells our code to not consult the cpm_logger to determine whether to copy. Always copy -- these are fixups!	
				InsertEbuilds(fixup_repo, ebuildloc=fixup_path, select="all", skip=None, replace=True, cpm_logger=cpm_logger, cpm_ignore=True )
			]
	tree.run(steps)

	# Now we want to perform a scan of any eclasses in the Gentoo repo that we need to copy over to our dest_kit so that it contains all
	# eclasses and licenses it needs within itself, without having to reference any in the Gentoo repo.

	copy_steps = []

	# For eclasses we perform a much more conservative scan. We will only scour missing eclasses from gentoo-staging, not
	# eclasses. If you need a special eclass, you need to specify it in the eclasses list for the overlay explicitly.

	last_count = None
	iterations = 0
	max_iterations = 16
	keep_going = True
	missing_eclasses = []

	# This loop is rather complicated to handle the case where we copy an eclass into our dest-kit, and this eclass in
	# turn requires additional eclasses, thus creating additional missing eclasses. So we need a super-loop to drive the
	# whole thing, and we keep going until the number of missing eclasses is zero.


	if tree.name != "core-kit":
	
		# for core-kit, we are going to include a COMPLETE set of eclasses, even unused ones, so that third-party overlays that
		# depend on any of these eclasses will find them and be able to use them.

		# All other kits get only the eclasses they actually use, so they have local copies of the versions of the eclasses with
		# which they were tested.

		while keep_going:
			for repo, elist in getAllEclasses(tree, gentoo_staging).items():
				repo_obj = None
				if repo == "dest_kit":
					# This means the eclass already exists in the kit -- probably copied from fixups
					continue
				elif repo == "parent_repo":
					# This means that the eclass is in gentoo_staging and needs to be copied
					repo_obj = gentoo_staging
				elif repo == None:
					if len(elist) == 0:
						keep_going = False
					elif len(elist) == last_count:
						# If there is something in elist, this means that the listed eclasses was nowhere to be found.
						iterations += 1
						if iterations > max_iterations:
							missing_eclasses = elist
							keep_going = False
				if repo_obj != None:
					copy_steps += [ InsertEclasses(repo_obj, select=elist) ]


	if iterations > max_iterations and len(missing_eclasses):
		print("!!! Error: The following eclasses were not found:")
		print("!!!      : " + " ".join(missing_eclasses))
		print("!!!      : Please be sure to use kit-fixups or the overlay's eclass list to copy these necessary eclasses into place.")
		sys.exit(1)

	# we need to get all the eclasses in place right away so that the following license extraction code has a 
	# chance of working correctly:

	tree.run(copy_steps)
	copy_steps = []

	# for licenses, we are going to aggressively scan all source repos for any missing licenses. We don't need to
	# be as anal about licenses as eclasses where slight differences can cause problems:

	not_found_licenses = {}

	for repo_dict in repos:
		for repo, elist in getAllLicenses(tree, repo_dict["repo"]).items():
			repo_obj = None
			if repo == "dest_kit":
				# already where we want them
				continue
			elif repo == "parent_repo":
				# found license in the parent repo/overlay
				repo_obj = repo_dict["repo"]
			elif repo == None:
				for license in elist:
					not_found_licenses[license] = repo_dict["repo"]
			for license in elist:
				if license in not_found_licenses:
					del not_found_licenses[license]
			if repo_obj:
				copy_steps += [ InsertLicenses(repo_obj, select=elist) ]

	if len(list(not_found_licenses)):
		# we scoured all our source repositories and these licenses were not found:
		print("!!! Error: The following eclasses were not found:")
		for license, repo in not_found_licenses.items():
			print("!!! %s license in %s" % (license, repo.name))
		print("!!!      : Please be sure to install these licenses in the source repository.")
		sys.exit(1)

	tree.run(copy_steps)

	# QA check: all eclasses should be in place. Let's confirm. if egencache is run without all eclasses in place, it hangs.

	result = getAllEclasses(tree)
	if None in result and len(result[None]):
		# we have some missing eclasses
		print("!!! Error: QA check on kit failed -- missing eclasses:")
		print("!!!      : " + " ".join(result[None]))
		print("!!!      : Please be sure to use kit-fixups or the overlay's eclass list to copy these necessary eclasses into place.")
		sys.exit(1)
	
	# Phase 4: finalize and commit

	# for core-kit, we want to grab CURRENT masks, etc, which is done by the post steps. But we want to grab eclasses and catpkgs from
	# the snapshot. So we temporarily switch to "master" for grabbing masks so they are current, and then switch back to the snapshot.

	if kit_dict["name"] == "core-kit":
		prev_branch = gentoo_staging.branch
		prev_sha1 = gentoo_staging.commit_sha1
		gentoo_staging.initializeTree("master")

	post_steps += [
		ELTSymlinkWorkaround(),
		CreateCategories(gentoo_staging),
		GenPythonUse("python3_4", "python2_7"),
		Minify(),
		GenUseLocalDesc(),
		GenCache( cache_dir="/var/cache/edb/%s-%s" % ( kit_dict['name'], kit_dict['branch'] ) )
	]

	tree.run(post_steps)
	tree.gitCommit(message="updates",branch=kit_dict['branch'],push=push)
	
	# now activate any regexes recorded as applied so that they will be matched against (and matches skipped) for successive kits:
	
	cpm_logger.nextKit()

if __name__ == "__main__":

	if len(sys.argv) != 2 or sys.argv[1] not in [ "push", "nopush" ]:
		print("Please specify push or nopush as an argument.")
		sys.exit(1)
	else:
		push = True if sys.argv[1] == "push" else False

	cpm_logger = CatPkgMatchLogger()

	for kit_group in kit_order: 
		if kit_group == None:
			cpm_logger = CatPkgMatchLogger()
		else:
			for kit_dict in kit_groups[kit_group]:
				print("Regenerating kit ",kit_dict)
				updateKit(kit_dict, cpm_logger, create=not push, push=push)

	print("Checking out prime versions of kits.")
	for kit_dict in kit_groups['prime'] + kit_groups['shared']:
		kit_dict["tree"].run([GitCheckout(branch=kit_dict['branch'])])
		if push:
			# use the github url for the submodule, for public consumption.
			meta_repo.gitSubmoduleAddOrUpdate(kit_dict["tree"], "kits/%s" % kit_dict["name"], "https://github.com/funtoo/%s.git" % kit_dict["name"])
	if push:
		meta_repo.gitCommit(message="kit updates", branch="master", push=push)

# vim: ts=4 sw=4 noet tw=140
