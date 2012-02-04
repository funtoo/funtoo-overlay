# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

cmd_exist()
{
	type "$1" >/dev/null 2>&1
}

if ! cmd_exist yesno; then
	yesno() {
		[ -z "$1" ] && return 1
		case "$1" in
			yes|Yes|YES) return 0 ;;
		esac
		return 1
	}
fi

if ! cmd_exist KV_to_int; then
	KV_to_int() {
		[ -z $1 ] && return 1

		local x=${1%%-*}
		local KV_MAJOR=${x%%.*}
		x=${x#*.}
		local KV_MINOR=${x%%.*}
		x=${x#*.}
		local KV_MICRO=${x%%.*}
		local KV_int=$((${KV_MAJOR} * 65536 + ${KV_MINOR} * 256 + ${KV_MICRO} ))

		# We make version 2.2.0 the minimum version we will handle as
		# a sanity check ... if its less, we fail ...
		[ "${KV_int}" -lt 131584 ] && return 1
	
		echo "${KV_int}"
	}
fi

if ! cmd_exist get_KV; then
	_RC_GET_KV_CACHE=""
	get_KV() {
		[ -z "${_RC_GET_KV_CACHE}" ] \
			&& _RC_GET_KV_CACHE="$(uname -r)"

		echo "$(KV_to_int "${_RC_GET_KV_CACHE}")"

		return $?
	}
fi

if ! cmd_exist fstabinfo; then
	fstabinfo() {
		[ "$1" = "--quiet" ] && shift
		local dir="$1"

		# only check RC_USE_FSTAB on baselayout-1
		if [ ! -e /lib/librc.so ]; then
			yesno "${RC_USE_FSTAB}" || return 1
		fi

		# check if entry is in /etc/fstab
		local ret=$(gawk 'BEGIN { found="false"; }
				  $1 ~ "^#" { next }
				  $2 == "'$dir'" { found="true"; }
				  END { print found; }
			    ' /etc/fstab)

		"${ret}"
	}
fi

