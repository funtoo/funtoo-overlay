# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

# functions that may not be defined, but are used by the udev-start and udev-stop addon
# used by baselayout-1 and openrc before version 0.4.0

cmd_exist()
{
	type "$1" >/dev/null 2>&1
}

# does not exist in baselayout-1, does exist in openrc
if ! cmd_exist yesno; then
	yesno() {
		[ -z "$1" ] && return 1
		case "$1" in
			yes|Yes|YES) return 0 ;;
		esac
		return 1
	}
fi

# does not exist in baselayout-1, does exist in openrc
#
# mountinfo <path>
# check if some filesystem is mounted at mountpoint <path>
#
# return value:
#   0 filesystem is mounted at <path>
#   1 no filesystem is mounted exactly at <path>
if ! cmd_exist mountinfo; then
	mountinfo() {
		[ "$1" = "-q" ] && shift
		local dir="$1"

		# check if entry is in /proc/mounts
		local ret=$(gawk 'BEGIN { found="false"; }
				  $1 ~ "^#" { next }
				  $2 == "'$dir'" { found="true"; }
				  END { print found; }
			    ' /proc/mounts)

		"${ret}"
	}
fi

# does not exist in baselayout-1, does exist in openrc
#
# used syntax:  fstabinfo --mount /dev
#   it should mount /dev if an entry exists in /etc/fstab
#
# return value:
#   0 mount succeeded
#   1 mount failed or no entry exists
#
if ! cmd_exist fstabinfo; then
	fstabinfo() {
		[ "$1" = "--mount" ] || return 1
		local dir="$2"

		# RC_USE_FSTAB does only exist in baselayout-1
		# this emulation is only needed on bl-1, so check always
		yesno "${RC_USE_FSTAB}" || return 1

		# no need to check fstab, mount does this already for us

		# try mounting - better first check fstab and then mount without surpressing errors
		mount -n "${dir}" 2>/dev/null
		return $?
	}
fi
