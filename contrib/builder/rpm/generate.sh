#!/bin/bash
set -e

# usage: ./generate.sh [versions]
#    ie: ./generate.sh
#        to update all Dockerfiles in this directory
#    or: ./generate.sh
#        to only update fedora-23/Dockerfile
#    or: ./generate.sh fedora-newversion
#        to create a new folder and a Dockerfile within it

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do
	distro="${version%-*}"
	suite="${version##*-}"
	from="${distro}:${suite}"
	installer=yum
	if [[ "$distro" == "fedora" ]]; then
		installer=dnf
	fi

	mkdir -p "$version"
	echo "$version -> FROM $from"
	cat > "$version/Dockerfile" <<-EOF
		#
		# THIS FILE IS AUTOGENERATED; SEE "contrib/builder/rpm/generate.sh"!
		#

		FROM $from
	EOF

	echo >> "$version/Dockerfile"

	extraBuildTags=

	case "$from" in
		centos:*)
			# get "Development Tools" packages dependencies
			echo 'RUN yum groupinstall -y "Development Tools"' >> "$version/Dockerfile"

			if [[ "$version" == "centos-7" ]]; then
				echo 'RUN yum -y swap -- remove systemd-container systemd-container-libs -- install systemd systemd-libs' >> "$version/Dockerfile"
			fi
			;;
		oraclelinux:*)
			# get "Development Tools" packages and dependencies
			echo 'RUN yum groupinstall -y "Development Tools"' >> "$version/Dockerfile"
			;;
		opensuse:*)
			# get rpm-build and curl packages and dependencies
			echo 'RUN zypper --non-interactive install ca-certificates* curl gzip rpm-build' >> "$version/Dockerfile"
			;;
		*)
			echo "RUN ${installer} install -y @development-tools fedora-packager" >> "$version/Dockerfile"
			;;
	esac

	# this list is sorted alphabetically; please keep it that way
	packages=(
		btrfs-progs-devel # for "btrfs/ioctl.h" (and "version.h" if possible)
		device-mapper-devel # for "libdevmapper.h"
		glibc-static
		libseccomp-devel # for "seccomp.h" & "libseccomp.so"
		libselinux-devel # for "libselinux.so"
		libtool-ltdl-devel # for pkcs11 "ltdl.h"
		selinux-policy
		selinux-policy-devel
		sqlite-devel # for "sqlite3.h"
		tar # older versions of dev-tools do not have tar
	)

	case "$from" in
		oraclelinux:7)
			# Enable the optional repository
			packages=( --enablerepo=ol7_optional_latest "${packages[*]}" )
			;;
	esac

	# opensuse & oraclelinx:6 do not have the right libseccomp libs
	# centos:7 and oraclelinux:7 have a libseccomp < 2.2.1 :(
	case "$from" in
		opensuse:*|oraclelinux:*|centos:7)
			packages=( "${packages[@]/libseccomp-devel}" )
			;;
		*)
			extraBuildTags+=' seccomp'
			;;
	esac

	case "$from" in
		opensuse:*)
			packages=( "${packages[@]/btrfs-progs-devel/libbtrfs-devel}" )
			# use zypper
			echo "RUN zypper --non-interactive install ${packages[*]}" >> "$version/Dockerfile"
			;;
		*)
			echo "RUN ${installer} install -y ${packages[*]}" >> "$version/Dockerfile"
			;;
	esac

	echo >> "$version/Dockerfile"

	# fedora does not have a libseccomp.a for compiling static dockerinit
	# ONLY install libseccomp.a from source, this can be removed once dockerinit is removed
	# TODO remove this manual seccomp compilation once dockerinit is gone or no longer needs to be statically compiled
	case "$from" in
		fedora:*)
			awk '$1 == "ENV" && $2 == "SECCOMP_VERSION" { print; exit }' ../../../Dockerfile >> "$version/Dockerfile"
			cat <<-'EOF' >> "$version/Dockerfile"
			RUN buildDeps=' \
				automake \
				libtool \
			' \
			&& set -x \
			&& yum install -y $buildDeps \
			&& export SECCOMP_PATH=$(mktemp -d) \
			&& git clone -b "$SECCOMP_VERSION" --depth 1 https://github.com/seccomp/libseccomp.git "$SECCOMP_PATH" \
			&& ( \
				cd "$SECCOMP_PATH" \
				&& ./autogen.sh \
				&& ./configure --prefix=/usr \
				&& make \
				&& install -c src/.libs/libseccomp.a /usr/lib/libseccomp.a \
				&& chmod 644 /usr/lib/libseccomp.a \
				&& ranlib /usr/lib/libseccomp.a \
				&& ldconfig -n /usr/lib \
			) \
			&& rm -rf "$SECCOMP_PATH"
			EOF

			echo >> "$version/Dockerfile"
			;;
		*) ;;
	esac

	awk '$1 == "ENV" && $2 == "GO_VERSION" { print; exit }' ../../../Dockerfile >> "$version/Dockerfile"
	echo 'RUN curl -fSL "https://storage.googleapis.com/golang/go${GO_VERSION}.linux-amd64.tar.gz" | tar xzC /usr/local' >> "$version/Dockerfile"
	echo 'ENV PATH $PATH:/usr/local/go/bin' >> "$version/Dockerfile"

	echo >> "$version/Dockerfile"

	echo 'ENV AUTO_GOPATH 1' >> "$version/Dockerfile"

	echo >> "$version/Dockerfile"

	# print build tags in alphabetical order
	buildTags=$( echo "selinux $extraBuildTags" | xargs -n1 | sort -n | tr '\n' ' ' | sed -e 's/[[:space:]]*$//' )

	echo "ENV DOCKER_BUILDTAGS $buildTags" >> "$version/Dockerfile"
done
