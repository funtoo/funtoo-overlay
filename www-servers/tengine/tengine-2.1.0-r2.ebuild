# Distributed under the terms of the GNU General Public License v2

EAPI="5"

GENTOO_DEPEND_ON_PERL="no"
# Passenger have support for jruby and rbx
USE_RUBY="ruby19 ruby20 ruby21 ruby22"
RUBY_OPTIONAL="yes"

declare -A mod{_a,_pn,_pv,_lic,_p,_uri,_wd,_doc}
declare -A mods

# encrypted_session depend on ndk.
# place ndk before modules that depend on it.

# Nginx Development Kit (NDK) (https://github.com/simpl/ngx_devel_kit)
mod_a["ndk"]="simpl"
mod_pn["ndk"]="ngx_devel_kit"
mod_pv["ndk"]="0.2.19"
mod_lic["ndk"]="BSD"
mod_p["ndk"]="${mod_pn["ndk"]}-${mod_pv["ndk"]}"
mod_uri["ndk"]="https://github.com/${mod_a["ndk"]}/${mod_pn["ndk"]}/archive/v${mod_pv["ndk"]}.tar.gz"
mod_wd["ndk"]="${WORKDIR}/${mod_p["ndk"]}"
mod_doc["ndk"]="README README_AUTO_LIB"

# Encrypted Session (https://github.com/openresty/encrypted-session-nginx-module)
mod_a["encrypted_session"]="openresty"
mod_pn["encrypted_session"]="encrypted-session-nginx-module"
mod_pv["encrypted_session"]="0.03"
mod_lic["encrypted_session"]="BSD-2"
mod_p["encrypted_session"]="${mod_pn["encrypted_session"]}-${mod_pv["encrypted_session"]}"
mod_uri["encrypted_session"]="https://github.com/${mod_a["encrypted_session"]}/${mod_pn["encrypted_session"]}/archive/v${mod_pv["encrypted_session"]}.tar.gz"
mod_wd["encrypted_session"]="${WORKDIR}/${mod_p["encrypted_session"]}"
mod_doc["encrypted_session"]="README"

# Fancy Index (https://github.com/aperezdc/ngx-fancyindex)
mod_a["fancyindex"]="aperezdc"
mod_pn["fancyindex"]="ngx-fancyindex"
mod_pv["fancyindex"]="0.3.5"
mod_lic["fancyindex"]="BSD-2"
mod_p["fancyindex"]="${mod_pn["fancyindex"]}-${mod_pv["fancyindex"]}"
mod_uri["fancyindex"]="https://github.com/${mod_a["fancyindex"]}/${mod_pn["fancyindex"]}/archive/v${mod_pv["fancyindex"]}.tar.gz"
mod_wd["fancyindex"]="${WORKDIR}/${mod_p["fancyindex"]}"
mod_doc["fancyindex"]="README.rst HACKING.md CHANGELOG.md"

# MogileFS Client (http://www.grid.net.ru/nginx/mogilefs.en.html)
mod_a["mogilefs"]="vkholodkov"
mod_pn["mogilefs"]="nginx-mogilefs-module"
mod_pv["mogilefs"]="1.0.4"
mod_lic["mogilefs"]="BSD"
mod_p["mogilefs"]="${mod_pn["mogilefs"]}-${mod_pv["mogilefs"]}"
mod_uri["mogilefs"]="https://github.com/${mod_a["mogilefs"]}/${mod_pn["mogilefs"]}/archive/${mod_pv["mogilefs"]}.tar.gz"
mod_wd["mogilefs"]="${WORKDIR}/${mod_p["mogilefs"]}"
mod_doc["mogilefs"]="README Changelog"

# Phusion Passenger (https://github.com/phusion/passenger)
mod_a["passenger"]="phusion"
mod_pn["passenger"]="passenger"
mod_pv["passenger"]="5.0.13"
mod_lic["passenger"]="MIT"
mod_p["passenger"]="${mod_pn["passenger"]}-release-${mod_pv["passenger"]}"
mod_uri["passenger"]="https://github.com/${mod_a["passenger"]}/${mod_pn["passenger"]}/archive/release-${mod_pv["passenger"]}.tar.gz"
mod_wd["passenger"]="${WORKDIR}/${mod_p["passenger"]}/ext/nginx"
mod_doc["passenger"]="README.md CHANGELOG"

inherit eutils flag-o-matic perl-module ruby-ng ssl-cert toolchain-funcs user

DESCRIPTION="Robust, small and high performance http and reverse proxy server"
HOMEPAGE="http://tengine.taobao.org"
SRC_URI="http://${PN}.taobao.org/download/${P}.tar.gz"

for m in ${!mod_a[@]} ; do
	SRC_URI+=" tengine_external_modules_http_${m}? (
		${mod_uri[$m]} -> ${mod_p[$m]}.tar.gz )"
done

LICENSE="BSD-2"

for m in ${!mod_a[@]} ; do
	LICENSE+=" tengine_external_modules_http_${m}? ( ${mod_lic[$m]} )"
done

RESTRICT="mirror"

SLOT="0"
KEYWORDS="*"

mods[upstream]="upstream_keepalive upstream_rbtree"

mods[upstream_shared]="upstream_ip_hash upstream_least_conn
	upstream_session_sticky"

mods[upstream_optional]="upstream_check upstream_consistent_hash"

mods[standard]="auth_basic geo gzip proxy ssi ssl stub_status"

mods[standard_shared]="access autoindex browser charset_filter empty_gif
	fastcgi footer_filter limit_conn limit_req map memcached referer
	reqstat rewrite scgi split_clients trim_filter userid_filter
	user_agent uwsgi"

mods[optional]="concat dav degradation gunzip gzip_static perl realip spdy"

mods[optional_shared]="addition flv geoip image_filter lua mp4 random_index
	secure_link slice tfs sub sysguard xslt"

mods[mail]="imap pop3 smtp"

IUSE="+aio +http +http-cache +pcre +poll +select +syslog
	backtrace debug google_perftools ipv6 jemalloc libatomic luajit
	pcre-jit rtsig ssl vim-syntax"

for m in ${mods[standard]} ${mods[upstream]}  ; do
	IUSE+=" +tengine_static_modules_http_${m}" ; done
for m in ${mods[standard_shared]} ${mods[upstream_shared]} ; do
	IUSE+=" tengine_shared_modules_http_${m}
		+tengine_static_modules_http_${m}" ; done
for m in ${mods[optional]} ${mods[upstream_optional]} ; do
	IUSE+=" tengine_static_modules_http_${m}" ; done
for m in ${mods[optional_shared]} ; do
	IUSE+=" tengine_shared_modules_http_${m}
		tengine_static_modules_http_${m}" ; done
for m in ${mods[mail]} ; do
	IUSE+=" tengine_modules_mail_${m}" ; done
for m in ${!mod_a[@]} ; do
	IUSE+=" tengine_external_modules_http_${m}" ; done

RDEPEND="http-cache? ( dev-libs/openssl )
	jemalloc? ( dev-libs/jemalloc )
	pcre? ( dev-libs/libpcre )
	pcre-jit? ( dev-libs/libpcre[jit] )
	ssl? ( dev-libs/openssl )

	tengine_shared_modules_http_geoip? ( dev-libs/geoip )
	tengine_shared_modules_http_image_filter? ( media-libs/gd[jpeg,png] )
	tengine_shared_modules_http_lua? ( !luajit? ( dev-lang/lua )
		luajit? ( dev-lang/luajit ) )
	tengine_shared_modules_http_rewrite? ( dev-libs/libpcre )
	tengine_shared_modules_http_secure_link? ( dev-libs/openssl )
	tengine_shared_modules_http_tfs? ( dev-libs/yajl )
	tengine_shared_modules_http_xslt? ( dev-libs/libxml2
		dev-libs/libxslt )

	tengine_static_modules_http_geo? ( dev-libs/geoip )
	tengine_static_modules_http_geoip? ( dev-libs/geoip )
	tengine_static_modules_http_gunzip? ( sys-libs/zlib )
	tengine_static_modules_http_gzip? ( sys-libs/zlib )
	tengine_static_modules_http_gzip_static? ( sys-libs/zlib )
	tengine_static_modules_http_image_filter? ( media-libs/gd[jpeg,png] )
	tengine_static_modules_http_lua? ( !luajit? ( dev-lang/lua )
		luajit? ( dev-lang/luajit ) )
	tengine_static_modules_http_perl? ( dev-lang/perl )
	tengine_static_modules_http_rewrite? ( dev-libs/libpcre )
	tengine_static_modules_http_secure_link? ( dev-libs/openssl )
	tengine_static_modules_http_spdy? ( dev-libs/openssl )
	tengine_static_modules_http_tfs? ( dev-libs/yajl )
	tengine_static_modules_http_xslt? ( dev-libs/libxml2
		dev-libs/libxslt )
	tengine_external_modules_http_passenger? (
		|| ( $(ruby_implementation_depend ruby19)
			$(ruby_implementation_depend ruby20)
			$(ruby_implementation_depend ruby21)
			$(ruby_implementation_depend ruby22) )
		dev-ruby/rake
		!!www-apache/passenger )"

DEPEND="${RDEPEND}
	arm? ( dev-libs/libatomic_ops )
	libatomic? ( dev-libs/libatomic_ops )"

PDEPEND="vim-syntax? ( app-vim/nginx-syntax )"

REQUIRED_USE="pcre-jit? ( pcre )
	tengine_external_modules_http_encrypted_session? ( ssl
		tengine_external_modules_http_ndk )
	tengine_external_modules_http_ndk? (
		tengine_static_modules_http_rewrite
		!tengine_shared_modules_http_rewrite )"

S="${WORKDIR}/${P}"

pkg_setup() {
	TENGINE_HOME="${EROOT}var/lib/${PN}"
	TENGINE_HOME_TMP="${TENGINE_HOME}/tmp"

	if egetent group ${PN} > /dev/null ; then
		elog "${PN} group already exist."
		elog "group creation step skipped."
	else
		enewgroup  ${PN} > /dev/null
		elog "${PN} group created by portage."
	fi

	if egetent passwd  ${PN} > /dev/null ; then
		elog "${PN} user already exist."
		elog "user creation step skipped."
	else
		enewuser ${PN} -1 -1 "${TENGINE_HOME}" \
			${PN} > /dev/null
		elog "${PN} user with ${TENGINE_HOME} home"
		elog "was created by portage."
	fi

	if use libatomic ; then
		ewarn "GCC 4.1+ features built-in atomic operations."
		ewarn "Using libatomic_ops is only needed if using"
		ewarn "a different compiler or a GCC prior to 4.1"
	fi

	if use tengine_external_modules_http_passenger ; then
		ruby-ng_pkg_setup
		use debug && append-flags -DPASSENGER_DEBUG
	fi

	if ! use http ; then
		ewarn "To actually disable all http-functionality you also have"
		ewarn "to disable all tengine http modules."
	fi

}

src_unpack() {
	# Prevent ruby-ng.eclass from messing with src_unpack
	default
}

src_prepare() {
	epatch "${FILESDIR}/${PN}-fix-perl-install-path.patch"

	sed -e "s;NGX_CONF_PREFIX/nginx.conf;NGX_CONF_PREFIX/tengine.conf;" \
		-i "${S}/auto/install" || die

	if ! use tengine_static_modules_http_charset_filter || \
		! use tengine_shared_modules_http_charset_filter ; then
			sed -e "s;--without-http_charset_module;--without-http_charset_filter_module;g" \
				-i "${S}/auto/options" || die
	fi

	if ! use tengine_static_modules_http_userid_filter || \
		! use tengine_shared_modules_http_userid_filter ; then
			sed -e "s;--without-http_userid_module;--without-http_userid_filter_module;g" \
				-i "${S}/auto/options" || die
	fi

	if ! use tengine_static_modules_http_upstream_rbtree ; then
		sed -e "s;--without-http-upstream-rbtree;--without-http_upstream_rbtree_module;g" \
			-i "${S}/auto/options" || die
	fi

	find auto/ -type f -print0 | \
		xargs -0 sed -i 's;\&\& make;\&\& \\$(MAKE);' || die
	# We have config protection, don't rename etc files
	sed -e "s;.default;;" \
		-i "${S}/auto/install" || die
	# Remove useless files
	sed -e "/koi-/d" \
		-e "/win-/d" \
		-i "${S}/auto/install" || die

	# Don't install to /etc/tengine/ if not in use
	local m
	for m in fastcgi scgi uwsgi ; do
		if ! use tengine_static_modules_http_${m} && \
			! use tengine_shared_modules_http_${m} ; then
				sed -e "/${m}/d" \
					-i "${S}/auto/install" || die
		fi
	done

	if use tengine_external_modules_http_passenger ; then
		cd ../"${mod_p[passenger]}"

		# Use proper toolchain-funcs methods
		sed -e "/^CC/ s/=.*$/= '$(tc-getCC)'/" \
			-e "/^CXX/ s/=.*$/= '$(tc-getCXX)'/" \
			-i "build/basics.rb" || die

		# Fix hard-coded use of AR
		sed -e "s;ar cru;"$(tc-getAR)" cru;" \
			-i "build/cplusplus_support.rb" || die

		epatch "${FILESDIR}"/passenger/passenger-contenthandler.patch
		epatch "${FILESDIR}"/passenger/passenger-gentoo.patch
		epatch "${FILESDIR}"/passenger/passenger-ldflags.patch

		sed -e "s;/buildout/agents;/agents;" \
			-i "ext/common/ResourceLocator.h" || die

		sed -e '/passenger-install-apache2-module/d' \
			-e "/passenger-install-nginx-module/d" \
			-i "lib/phusion_passenger/packaging.rb" || die

		rm "bin/passenger-install-apache2-module" \
			"bin/passenger-install-nginx-module" || \
			die "Unable to remove nginx and apache2 installation scripts."

		cd "${mod_wd[passenger]}"
		_ruby_each_implementation passenger_premake
	fi
}

src_configure() {
	local tengine_configure= http_enabled= mail_enabled=
	local disabled= shared= static= static_and_shared=

	use aio && tengine_configure+=" --with-file-aio --with-aio_module"
	use backtrace && tengine_configure+=" --with-backtrace_module"
	use debug && tengine_configure+=" --with-debug"
	use google_perftools && tengine_configure+=" --with-google_perftools_module"
	use ipv6 && tengine_configure+=" --with-ipv6"
	use jemalloc && tengine_configure+=" --with-jemalloc"
	use libatomic && tengine_configure+=" --with-libatomic"
	use pcre && tengine_configure+=" --with-pcre"
	use pcre-jit && tengine_configure+=" --with-pcre-jit"
	use rtsig && tengine_configure+=" --with-rtsig_module"

	use syslog || tengine_configure+=" --without-syslog"

	for m in ${mods[upstream]}  ${mods[upstream_shared]} \
		${mods[upstream_optional]} \
		${mods[standard]} ${mods[standard_shared]} \
		${mods[optional]} ${mods[optional_shared]} ; do

		use_if_iuse "tengine_shared_modules_http_${m}" && \
		use_if_iuse "tengine_static_modules_http_${m}" && \
		static_and_shared+=" ${m}"

		use_if_iuse "tengine_shared_modules_http_${m}" && \
		! use_if_iuse "tengine_static_modules_http_${m}" && \
		shared_only+=" ${m}"

		use_if_iuse "tengine_static_modules_http_${m}" && \
		! use_if_iuse "tengine_shared_modules_http_${m}" && \
		static_only+=" ${m}"

		! use_if_iuse "tengine_shared_modules_http_${m}" && \
		! use_if_iuse "tengine_static_modules_http_${m}" && \
		disabled+=" ${m}"
	done

	einfo "Both static and shared variants of these modules was enabled:"
	einfo "${static_and_shared}"
	einfo "We favor shared modules and shared variant will be compiled."

	einfo "Shared variant of these modules was enabled:"
	einfo "${shared_only}"

	einfo "Static variant of these modules was enabled:"
	einfo "${static_only}"

	einfo "These modules will be disabled:"
	einfo "${disabled}"

	for m in $shared_only $shared_and_static ; do
		http_enabled=1
		tengine_configure+=" --with-http_${m}_module=shared"
	done

	for m in $static_only ; do
		egrep -q "\b${m}\b" <<< ${mods[upstream]} && \
			http_enabled=1

		egrep -q "\b${m}\b" <<< ${mods[upstream_shared]} && \
			http_enabled=1

		egrep -q "\b${m}\b" <<< ${mods[upstream_optional]} && \
			http_enabled=1 && \
			tengine_configure+=" --with-http_${m}_module"

		egrep -q "\b${m}\b" <<< ${mods[standard]} && \
			http_enabled=1

		egrep -q "\b${m}\b" <<< ${mods[standard_shared]} && \
			http_enabled=1

		egrep -q "\b${m}\b" <<< ${mods[optional]} && \
			http_enabled=1 && \
			tengine_configure+=" --with-http_${m}_module"

		egrep -q "\b${m}\b" <<< ${mods[optional_shared]} && \
			http_enabled=1 && \
			tengine_configure+=" --with-http_${m}_module"
	done

	sleep 10

	for m in $disabled ; do
		egrep -q "\b${m}\b" <<< ${mods[{standard,_shared}]} && \
			tengine_configure+=" --without-http_${m}_module"
	done

	for m in ${!mod_a[@]} ; do
		 use tengine_external_modules_http_${m} && \
			http_enabled=1 && \
			tengine_configure+=" --add-module=${mod_wd[$m]}"
	done

	if use http || use http-cache ; then
		http_enabled=1
	fi

	if [[ -n "${http_enabled}" ]] ; then
		use http-cache || tengine_configure+=" --without-http-cache"
		use ssl && tengine_configure+=" --with-http_ssl_module"
	else
		tengine_configure+=" --without-http --without-http-cache"
	fi

	for m in ${mods[mail]} ; do
		use tengine_modules_mail_${m} && \
			mail_enabled=1 || \
			tengine_configure+=" --without-mail_${m}_module"
	done

	if [[ -n "${mail_enabled}" ]] ; then
		tengine_configure+=" --with-mail"
		use ssl && tengine_configure+=" --with-mail_ssl_module"
	fi

	# https://bugs.gentoo.org/286772
	export LANG=C LC_ALL=C
	tc-export CC

	if ! use prefix ; then
		tengine_configure+=" \
			--user=${PN} \
			--group=${PN}"
	fi

	./configure \
		--sbin-path="${EPREFIX}/usr/sbin/${PN}" \
		--dso-path="${EPREFIX}/${TENGINE_HOME}/modules" \
		--dso-tool-path="${EPREFIX}/usr/sbin/dso_tool" \
		--prefix="${EPREFIX}/usr" \
		--conf-path="${EPREFIX}/etc/${PN}/${PN}.conf" \
		--error-log-path="${EPREFIX}/var/log/${PN}/error_log" \
		--pid-path="${EPREFIX}/run/${PN}.pid" \
		--lock-path="${EPREFIX}/run/lock/${PN}.lock" \
		--with-cc-opt="-I${EROOT}usr/include" \
		--with-ld-opt="-L${EROOT}usr/$(get_libdir)" \
		--http-log-path="${EPREFIX}/var/log/${PN}/access_log" \
		--http-client-body-temp-path="${EPREFIX}/${TENGINE_HOME_TMP}/client" \
		--http-proxy-temp-path="${EPREFIX}/${TENGINE_HOME_TMP}/proxy" \
		--http-fastcgi-temp-path="${EPREFIX}/${TENGINE_HOME_TMP}/fastcgi" \
		--http-scgi-temp-path="${EPREFIX}/${TENGINE_HOME_TMP}/scgi" \
		--http-uwsgi-temp-path="${EPREFIX}/${TENGINE_HOME_TMP}/uwsgi" \
		$(use_with poll poll_module) \
		$(use_with select select_module) \
		${tengine_configure} || die

	# A purely cosmetic change that makes tengine -V more readable.
	# This can be good if people outside the gentoo community would
	# troubleshoot and question the user setup.
	sed -e "s;${WORKDIR};external_module;g" \
		-i "${S}/objs/ngx_auto_config.h" || die
}

src_compile() {
	# https://bugs.gentoo.org/286772
	export LANG=C LC_ALL=C
	emake LINK="${CC} ${LDFLAGS}" OTHERLDFLAGS="${LDFLAGS}"
}

passenger_premake() {
	# Dirty spike to make passenger compilation each-ruby compatible
	mkdir -p "${S}"
	cp -r "${mod_p[passenger]}" "${S}"
	cp -r "${PN}-${PV}" "${S}"
	cd "${S}/${mod_p[passenger]}"
	sed -e "s;#{PlatformInfo.ruby_command};${RUBY};g" \
		-i "build/ruby_extension.rb" \
		-i "lib/phusion_passenger/native_support.rb" || die
	append-cflags $(test-flags-CC -fno-strict-aliasing -Wno-unused-result)
	append-cxxflags $(test-flags-CXX -fno-strict-aliasing -Wno-unused-result -fPIC)
	rake -m nginx || die "Passenger premake for ${RUBY} failed!"
}

passenger_install() {
	# Dirty spike to make passenger installation each-ruby compatible
	cd "${mod_wd[passenger]}"
	rake -m fakeroot \
	NATIVE_PACKAGING_METHOD=ebuild \
	FS_PREFIX="${EPREFIX}/usr" \
	FS_DATADIR="${EPREFIX}/usr/libexec" \
	FS_DOCDIR="${EPREFIX}/usr/share/doc/${P}" \
	FS_LIBDIR="${EPREFIX}/usr/$(get_libdir)" \
	RUBYLIBDIR="$(ruby_rbconfig_value 'archdir')" \
	RUBYARCHDIR="$(ruby_rbconfig_value 'archdir')" \
	|| die "Passenger installation for ${RUBY} failed!"
}

src_install() {
	if use tengine_static_modules_http_perl ; then
		sed -e '/CORE_LINK/{ N; s/CORE_LINK=.\(.*\).$/CORE_LINK="\1"/ }' \
			-i "${S}/objs/dso_tool" || die
	fi

	emake DESTDIR="${ED}" install

	insinto "${EROOT}etc/${PN}"
	doins "${FILESDIR}/${PN}.conf"

	newinitd "${FILESDIR}/${PN}.initd" "${PN}"

	keepdir "${EROOT}etc/${PN}"/sites-{available,enabled}
	insinto "${EROOT}etc/${PN}/sites-available"
	doins "${FILESDIR}/sites-available/localhost"
	dodir "${EROOT}usr/share/tengine/html"
	insinto "${EROOT}usr/share/tengine/html"
	doins "${FILESDIR}/example/index.html"
	doins "${FILESDIR}/example/powered-by-funtoo.png"
	doins "${FILESDIR}/example/tengine-logo.png"

	newman man/nginx.8 ${PN}.8
	dodoc CHANGES* README

	keepdir "${EROOT}var/www/localhost"
	rm -r "${ED}usr/html" || die

	local keepdir_list="${TENGINE_HOME_TMP}/client"
	local m
	for m in proxy fastcgi scgi uwsgi ; do
		use tengine_static_modules_http_${m} && \
			keepdir_list+=" ${TENGINE_HOME_TMP}/${m}"
	done

	# logrotate
	if use syslog ; then
		insinto "${EROOT}etc/logrotate.d"
		newins "${FILESDIR}/${PN}.logrotate" "${PN}"
		if [[ ! -d "${EROOT}var/log/${PN}" ]] ; then
			keepdir_list+=" ${EROOT}var/log/${PN}"
		fi
	fi

	keepdir ${keepdir_list}
	fperms 0700 ${keepdir_list}
	fowners ${PN}:${PN} ${keepdir_list}

	if use tengine_static_modules_http_perl ; then
		cd "${S}/objs/src/http/modules/perl"
		emake DESTDIR="${ED}" INSTALLDIRS=vendor install
		perl_delete_localpod
	fi

	if use tengine_external_modules_http_passenger ; then
		_ruby_each_implementation passenger_install
	fi

	for m in ${!mod_a[@]} ; do
		if use tengine_external_modules_http_${m} ; then
			docinto "${mod_p[$m]}"
			for d in ${mod_doc[$m]} ; do
				dodoc ${WORKDIR}/${mod_p[$m]}/${d} ; done
		fi
	done
}

pkg_preinst() {
	if [[ ! -d "${EROOT}etc/${PN}/sites-available" ]] ; then
		first_install=yes
	else
		first_install=no
	fi
}

pkg_postinst() {
	if [[ "${first_install}" = "yes" ]] && \
		[[ ! -e "${EROOT}etc/${PN}/sites-enabled/localhost" ]] ; then
			einfo "Enabling example Web site (see http://127.0.0.1)"
			ln -s "../sites-available/localhost" \
				"${EROOT}etc/${PN}/sites-enabled/localhost" || \
				die
	fi

	if use ssl ; then
		if [[ ! -f "${EROOT}etc/ssl/${PN}/${PN}.key" ]] ; then
			install_cert /etc/ssl/${PN}/${PN}
			use prefix || \
				chown \
				${PN}:${PN} \
				"${EROOT}etc/ssl/${PN}"/${PN}.{crt,csr,key,pem}
		fi
	fi

	einfo "If tengine complains about insufficient number of open files at"
	einfo "start, ensure that you have a correct /etc/security/limits.conf"
	einfo "and then do relogin to your system to ensure that the new max"
	einfo "open file limits are active. Then try restarting tengine again."

	if use tengine_external_modules_http_passenger ; then
		ewarn "Please, keep notice, that 'passenger_root' directive"
		ewarn "should point to exact location of 'locations.ini'"
		ewarn "file from this package (i.e. it should be full path)"
		ewarn "It is installed (by default) to"
		ewarn "${EROOT}usr/libexec/passenger/locations.ini"
	fi

	# If the tengine user can't change into or read the dir, display a warning.
	# If su is not available we display the warning nevertheless since
	# we can't check properly
	su -s /bin/sh -c "cd ${EROOT}var/log/${PN} && ls" ${PN} >&/dev/null
	if [[ $? -ne 0 ]] ; then
		ewarn "Please make sure that the (${PN}) user"
		ewarn "or (${PN}) group has"
		ewarn "at least 'rx' permissions (default on fresh install)"
		ewarn "on ${EROOT}var/log/${PN} directory."
		ewarn "Otherwise you end up with empty log files"
		ewarn "after a logrotate."
	fi
}
