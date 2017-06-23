#!/usr/bin/python3

import os
from merge_utils import *

# KIT DESIGN AND DEVELOPER DOCS

# The maintainable model for kits is to have a 'fixups' repository that contains our changes. Then, this file is used to
# automatically generate the kits. Rather than commit directly to the kits, we just maintain fix-ups and this file's meta-
# data.

# We record the source sha1 for creating the fixup from Gentoo. Kit generation should be automated. We simply maintain the
# fix-ups and the source sha1's from gentoo for each branch, and then can have this script regenerate the branches with the
# latest fix-ups. That way, we don't get our changes mixed up with Gentoo's ebuilds.

# A kit is generated from:

# 1. a list of ebuilds, eclasses, licenses to select
# 2. a source repository and SHA1 (we want to map to Gentoo's gentoo-staging repo)
# 3. a collection of fix-ups (from a fix-up repository) that are applied on top (generally, we will replace catpkgs underneath)

# Below, the kits and branches should be defined in a way that includes all this information. It is also possible to
# have a kit that simply is a collection of ebuilds but tracks the latest gentoo-staging. It may or may not have additional
# fix-ups.

# Kits have benefits over shards, in that because they exist on the user's system, they can control which branch they are running
# for each kit. And the goal of the kits is to have a very well-curated selection of relevant packages. At first, we may just
# have a few kits that are carefully selected, and we may have larger collections that we create just to get the curation process
# started. Examples below are text-kit and net-kit, which are very large groups of ebuilds.

# When setting up a kit repository, the 'master' branch is used to store an 'unfrozen' kit that just tracks upstream
# Gentoo. Kits are not required to have a master branch -- we only create one if the kit is designed to offer unfrozen
# ebuilds to Funtoo users.	Examples below are: science-kit, games-kit, text-kit, net-kit.

# If we have a frozen enterprise branch that we are backporting security fixes to only, we want this to be an
# 'x.y-prime' branch. This branch's source sha1 isn't supposed to change and we will just augment it with fix-ups as
# needed.

# As kits are maintained, the following things may change:
#
# 1. The package list may change. This can result in different packages being selected for the kit the next time it
#	 is regenerated by this script. We can add mising packages, decide to move packages to other kits, etc. This script
#	 takes care of ensuring that all necessary ebuilds and licenses are included when the kit is regenerated.
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
# 6. The 'regeneration priority' of kits can be changed. (See below)
#
# 7. The 'catpkg ignore list' of kits can be changed (Not yet implemented.) This would allow python-kit to include all
#	 dev-python/* catpkgs except for one or two that should be logically grouped with the gnome-kit, even if python-kit
#	 has a 'dev-python/*' selector in its catpkg list.

# 8. A kit git repository may be destroyed and recreated, but keep the same clone URL. This is very likely to happen
#	 during the beta period but may also happen in production. Any tool that manages meta-repo submodules should have the
#	 ability to detect when a stale repo has been cloned and remove it and replace it with a current clone. I am not sure
#	 if git has this functionality built-in, but it could be implemented by our repo management tool by manually recording
#	 the SHA1 of the first commit in a branch which can be used to verify whether the repo is in fact current or needs to
#	 be re-cloned from the source.

# HOW KITS ARE GENERATED

# Currently, kits are regenerated in a particluar order, such as: "first, core-kit, then security-kit, then perl-kit",
# etc. This script keeps a running list of catpkgs that are inserted into each kit. Once a catpkg is inserted into a
# kit, it is not available to be inserted into successive kits. This design is intended to prevent multiple copies of
# catpkgs existing in multiple kits in parallel. At the end of kit generation, this master list of inserted catpkgs is
# used to prune the 'nokit' repository of catpkgs, so that 'nokit' contains the set of all ebuilds that were not
# inserted into kits.

# OVERLAYS - lists sources for catpkgs, along with properties which can include "select" - a list of catpkgs to include.
# When "select" is specified, only these ebuilds will be included. If no "select" is specified, then by default all
# available catpkgs could be included, if they match patterns, etc. in package sets. Note that we do not specify branch
# or SHA1 here, as this may depend on other factors. See KIT SOURCES, below.

overlays = {
	"gentoo-staging" : { "type" : GitTree, "url" : "repos@git.funtoo.org:ports/gentoo-staging.git" },
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

funtoo_overlay = GitTree("funtoo-overlay", "master", "repos@git.funtoo.org:funtoo-overlay.git", pull=True)
fixup_repo = GitTree("kit-fixups", "master", "repos@git.funtoo.org:kits/kit-fixups.git", pull=True)

# meta_repo = GitTree("meta-repo", "master", "repos@git.funtoo.org:kits/meta-repo.git", pull=True)

# KIT SOURCES - kit sources are a combination of overlays, arranged in a python list [ ]. Order is important -- they
# are processed in order and the last overlay listed will have the ability to overwrite catpkgs from previous overlays.
# A KIT SOURCE serves as a unified collection of source catpkgs for a particular kit. Each kit can have one KIT SOURCE.
# KIT SOURCEs can be shared among kits to avoid duplication and to help organization. Note that this is where we specify
# branch or SHA1.

# It is important to note that we support three kinds of kit sources -- the first kind is a repository which not not have
# another master repository that it uses. The second kind is a special case of the first, where we are copying from the
# 'gentoo' repository. The third case we support is copying from an overlay that is designed to have 'gentoo' as master.
# We only support these specific combinations. The gentoo repository should appear first in the list, with other overlays
# appearing after.

kit_source_defs = {
	"gentoo_current" : [
		{ "repo" : "gentoo-staging", "src_branch" : 'master'},
		{ "repo" : "flora", "src_branch" : 'master' },
		{ "repo" : "faustoo", "src_branch" : 'master' },
		{ "repo" : "fusion809", "src_branch" : 'master' }
	],
	"gentoo_prime" : [
		{ "repo" : "gentoo-staging", "src_branch" : '06a1fd99a3ce1dd33724e11ae9f81c5d0364985e', 'date' : '21 Apr 2017'},
		{ "repo" : "flora", "src_branch" : 'master' },
		{ "repo" : "faustoo", "src_branch" : "58c805ec0df34cfc699e6555bf317590ff9dee15", },
		{ "repo" : "fusion809", "src_branch" : "8322bcd79d47ef81f7417c324a1a2b4772020985", "options" : { "merge" : True }},
	],
	"gentoo_prime_xorg" : [
		{ "repo" : "gentoo-staging", 'src_branch' : 'a56abf6b7026dae27f9ca30ed4c564a16ca82685', 'date' : '18 Nov 2016' }
	],
	"gentoo_prime_gnome" : [
		{ "repo" : "gentoo-staging", 'src_branch' : '44677858bd088805aa59fd56610ea4fb703a2fcd', 'date' : '18 Sep 2016' }
	],
	"gentoo_prime_media" : [
		{ "repo" : "gentoo-staging", 'src_branch' : '355a7986f9f7c86d1617de98d6bf11906729f108', 'date' : '25 Feb 2017' }
	],
	"gentoo_prime_perl" : [
		{ "repo" : "gentoo-staging", 'src_branch' : 'fc74d3206fa20caa19b7703aa051ff6de95d5588', 'date' : '11 Jan 2017' }
	]
}

kit_source_instances = { }

# KIT GROUPS - this is where kits are actually defined. They are organized by GROUP: 'prime', 'current', or 'shared'.
# 'prime' kits are production-quality kits. Current kits are bleeding-edge kits. 'shared' kits are used by both 'prime'
# and 'current' -- they can have some "prime" kits as well as some "current" kits depending on what we want to stabilize.
# Note that we specify a 'source' which points to a name of a kit_source to use as a source of ebuilds.

kit_groups = {
	'prime' : [
		{ 'name' : 'core-kit', 'branch' : '1.0-prime', 'source': 'gentoo_prime' },
		{ 'name' : 'security-kit', 'branch' : '1.0-prime', 'source': 'gentoo_prime' },
		{ 'name' : 'xorg-kit', 'branch' : '1.17-prime', 'source': 'gentoo_prime_xorg' },
	],
	'current' : [
		{ 'name' : 'core-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'security-kit', 'branch' : 'master', 'source': 'gentoo_current' },
		{ 'name' : 'xorg-kit', 'branch' : 'master', 'source': 'gentoo_current' },
	],
	'shared' : [
		{ 'name' : 'gnome-kit', 'branch' : '3.20-prime', 'source': 'gentoo_prime_gnome' },
		{ 'name' : 'media-kit', 'branch' : '1.0-prime', 'source': 'gentoo_prime_media' },
		{ 'name' : 'perl-kit', 'branch' : '5.24-prime', 'source': 'gentoo_prime_perl' },
		{ 'name' : 'python-kit', 'branch' : '3.4-prime', 'source': 'gentoo_prime' },
		{ 'name' : 'php-kit', 'branch' : '7.1.3-prime', 'source': 'gentoo_prime' },
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
	]
}

kit_order = [ 'prime', 'shared', None, 'current' ]

# When we update kits, we keep a record of catpkgs inserted into each kit, in a dict called "kitted_catpkgs". Once a
# catpkg is inserted into a kit, it's no longer 'available' to be inserted into successive kits, to avoid duplicates.

# We want to reset 'kitted_catpkgs' at certain points. The 'kit_order' variable below is used to control this, and
# we normally don't want to touch it. 'kitted_catpkgs' below tells the code to generate 'prime', then 'shared' (without
# resetting kitted_catpkgs), then the None tells the code to reset kitted_catpkgs, so when 'current' kits are generated,
# they can include from all possible catpkgs.

def getKitPrepSteps(repos, kit_dict, gentoo_staging):

	global funtoo_overlay

	kit_steps = {
		'core-kit' : { 'pre' : [
				GenerateRepoMetadata("core-kit", aliases=["gentoo"], priority=1000),
				SyncDir(gentoo_staging.root, "profiles", exclude=["repo_name"]),
				SyncDir(funtoo_overlay.root, "profiles", "profiles", exclude=["repo_name", "categories", "updates"]),
				SyncDir(gentoo_staging.root, "metadata", exclude=["cache","md5-cache","layout.conf"]),
				SyncFiles(funtoo_overlay.root, {
						"COPYRIGHT.txt":"COPYRIGHT.txt",
						"LICENSE.txt":"LICENSE.txt",
					}),
				ThirdPartyMirrors(),
				RunSed(["profiles/base/make.defaults"], ["/^PYTHON_TARGETS=/d", "/^PYTHON_SINGLE_TARGET=/d"]),
				CopyAndRename("profiles/funtoo/1.0/linux-gnu/arch/x86-64bit/subarch", "profiles/funtoo/1.0/linux-gnu/arch/pure64/subarch", lambda x: os.path.basename(x) + "-pure64"),
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
				SyncFiles(funtoo_overlay.root, {
					"profiles/package.mask/funtoo-toolchain":"profiles/funtoo/1.0/linux-gnu/build/current/package.mask/funtoo-toolchain",
					"profiles/package.mask/funtoo-toolchain":"profiles/funtoo/1.0/linux-gnu/build/stable/package.mask/funtoo-toolchain",
					"profiles/package.mask/funtoo-toolchain-experimental":"profiles/funtoo/1.0/linux-gnu/build/experimental/package.mask/funtoo-toolchain",
				}),
				ProfileDepFix()
			]
		},
		'python-kit' : { 'post' : [
				AutoGlobMask("dev-lang/python", "python*_pre*", "funtoo-python_pre"),
			]
		},
		'xorg-kit' : { 'post' : [
				AutoGlobMask("media-libs/mesa", "mesa*_rc*", "funtoo-mesa_rc"),
			]
		},
		'regular-kits' : { 'pre' : [
			GenerateRepoMetadata(kit_dict['name'], masters=[], priority=500),
			]
		},
		'nokit' : { 'pre' : [
				SyncDir(gentoo_staging.root),
				GenerateRepoMetadata("nokit", masters=[], priority=-2000),
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

	return ( out_pre_steps, out_copy_steps, out_post_steps )

def getKitSourceInstance(kit_dict):

	global kit_source_instances
	global kit_source_defs
	
	source_name = kit_dict['source']

	if source_name in kit_source_instances:
		return kit_source_instances[source_name]

	repos = []

	source_defs = kit_source_defs[source_name]

	for source_def in source_defs:

		repo_name = source_def['repo']
		repo_branch = source_def['src_branch']
		repo_obj = overlays[repo_name]["type"]
		repo_url = overlays[repo_name]["url"]

		repo = repo_obj(repo_name, url=repo_url, branch=repo_branch)
		repo.run([GitCheckout(repo_branch)])

		if "options" in source_def:
			sro = source_def["options"].copy()
		else:
			sro = {}
		if "select" in overlays[repo_name]:
			sro["select"] = overlays[repo_name]["select"]

		repos.append( { "name" : repo_name, "repo" : repo, "options" : sro } )

	kit_source_instances[source_name] = repos
	return repos

def updateKit(kit_dict, kitted_catpkgs, create=False):

	# get set of source repos used to grab catpkgs from:

	repos = getKitSourceInstance(kit_dict)
	print("MY REPOS")
	for repo in repos:
		print(repo["name"])

	gentoo_staging = None
	for x in repos:
		if x["name"] == "gentoo-staging":
			gentoo_staging = x["repo"]
			break
	if gentoo_staging == None:
		print("Couldn't find source gentoo staging repo")
	elif gentoo_staging.name != "gentoo-staging":
		print("Gentoo staging mismatch -- name is %s" % gentoo_staging["name"])

	# create kit repo if it doesn't exist

	if create and not os.path.exists('/var/git/dest-trees/%s' % kit_dict['name']):
		os.makedirs('/var/git/dest-trees/%s' % kit_dict['name'])
		os.system('cd /var/git/dest-trees/%s' % kit_dict['name'] + ' ;git init; touch README; git add README; git commit -a -m "first commit"')
		if kit_dict['branch'] != 'master':
			# create branch
			os.system('cd /var/git/dest-trees/%s' % kit_dict['name'] + ' ;git checkout -b %s' % kit_dict['branch'])
	kit_dict['tree'] = tree = GitTree(kit_dict['name'], kit_dict['branch'], "repos@git.funtoo.org:kits/%s.git" % kit_dict['name'], root="/var/git/dest-trees/%s" % kit_dict['name'], pull=True)
	
	# Phase 1: prep the kit
	pre_steps = [
		GitCheckout(kit_dict['branch']),
		CleanTree()
	]
	
	prep_steps = getKitPrepSteps(repos, kit_dict, gentoo_staging)
	pre_steps += prep_steps[0]
	copy_steps = prep_steps[1]
	post_steps = prep_steps[2]

	if kit_dict['name'] == 'nokit':
		# SPECIAL NOKIT STEPS START
		# perform these steps only, then return from this function. nokit has a special set of steps
		pre_steps += [
			RemoveFiles(list(kitted_catpkgs.keys())),
		]
		tree.run(pre_steps)
		# SPECIAL NOKIT STEPS END
	else:
		tree.run(pre_steps)

		# Phase 2: copy core set of ebuilds

		# Here we generate our main set of ebuild copy steps, based on the contents of the package-set file for the kit. The logic works as
		# follows. We apply our package-set logic to each repo in succession. If copy ebuilds were actually copied (we detect this by
		# looking for changed catpkg count in our dest_kit,) then we also run additional steps: "copyfiles" and "eclasses". "copyfiles"
		# specifies files like masks to copy over to the dest_kit, and "eclasses" specifies eclasses from the overlay that we need to
		# copy over to the dest_kit. We don't need to specify eclasses that we need from gentoo_staging -- these are automatically detected
		# and copied, but if there are any special eclasses from the overlay then we want to copy these over initially.

		steps = []

		cat_dict_count = len(kitted_catpkgs.keys())
		for repo_dict in repos:
			steps += generateShardSteps(kit_dict['name'], repo_dict["repo"], tree, gentoo_staging, pkgdir=funtoo_overlay.root+"/funtoo/scripts", branch=kit_dict['branch'], insert_kwargs=repo_dict["options"], catpkg_dict=kitted_catpkgs)
			new_cat_dict_count = len(kitted_catpkgs.keys())
			if cat_dict_count != new_cat_dict_count:
				# this means some catpkgs were installed from the repo we are currently processing. This means we also want to execute
				# 'copyfiles' and 'eclasses' copy logic:
				
				ov = overlays[repo_dict["name"]]

				if "copyfiles" in ov and len(ov["copyfiles"]):
					# since we copied over some ebuilds, we also want to make sure we copy over things like masks, etc:
					steps += SyncFiles(repo_dict["repo"].root, ov["copyfiles"])
				if "eclasses" in ov:
					# we have eclasses to copy over, too:
					ec_files = []
					for eclass in ov["eclasses"]:
						ec_files = "/eclass/" + eclass + ".eclass"
						steps += SyncFiles(repo_dict["repo"].root, ec_files)

			# update catpkg count for detecting new catpkgs on next iteration of our main 'for' loop:
			cat_dict_count = new_cat_dict_count
			
		tree.run(steps)

		# Phase 3: copy eclasses, licenses, and ebuild/eclass fixups from the kit-fixups repository. 

		# First, we are going to process the kit-fixups repository and look for ebuilds and eclasses to replace. Eclasses can be
		# overridden by using the following paths inside kit-fixups:

		# kit-fixups/eclass <--------------------- global eclasses, get installed to all kits unconditionally (overrides those above)
		# kit-fixups/<kit>/global/eclass <-------- global eclasses for a particular kit, goes in all branches (overrides those above)
		# kit-fixups/<kit>/<branch>/eclass <------ eclasses to install in just a specific branch of a specific kit (overrides those above)

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
				steps += [
					# add a new parameter called 'prefix'
					InsertEbuilds(fixup_repo, ebuildloc=fixup_path, select="all", skip=None, replace=True )
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

		while keep_going:
			print("Starting missing eclass stuff")
			for repo, elist in getAllEclasses(tree, gentoo_staging).items():
				repo_obj = None
				print("missing eclass iteration")
				print(repo, elist)
				if repo == "dest_kit":
					# already where we want them
					continue
				elif repo == "parent_repo":
					repo_obj = gentoo_staging
				elif repo == None:
					if len(elist) == 0:
						keep_going = False
					elif len(elist) == last_count:
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

	post_steps += [
		ELTSymlinkWorkaround(),
		CreateCategories(gentoo_staging),
		Minify(),
		GenUseLocalDesc(),
		GenCache( cache_dir="/var/cache/edb/%s-%s" % ( kit_dict['name'], kit_dict['branch'] ) )
	]
	tree.run(post_steps)
	tree.gitCommit(message="updates",branch=kit_dict['branch'],push=False)

if __name__ == "__main__":

	kitted_catpkgs = {}

	for kit_group in kit_order: 
		if kit_group == None:
			kitted_catpkgs = {}
		else:
			for kit_dict in kit_groups[kit_group]:
				print("Regenerating kit ",kit_dict)
				updateKit(kit_dict, kitted_catpkgs, create=True)

	print("Checking out prime versions of kits.")
	for kit_dict in kit_groups['prime']:
		kit_dict['kit'].run([GitCheckout(branch=kit_dict['branch'])])

# vim: ts=4 sw=4 noet tw=140
