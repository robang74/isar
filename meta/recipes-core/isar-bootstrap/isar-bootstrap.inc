# Minimal debian root file system
#
# This software is a part of ISAR.
# Copyright (c) Siemens AG, 2018-2021
#
# SPDX-License-Identifier: MIT

LICENSE = "gpl-2.0"
LIC_FILES_CHKSUM = "file://${LAYERDIR_core}/licenses/COPYING.GPLv2;md5=751419260aa954499f7abaabaa882bbe"
FILESPATH:prepend := "${THISDIR}/files:"
SRC_URI = " \
    file://locale \
    file://chroot-setup.sh"
PV = "1.0"

BOOTSTRAP_FOR_HOST ?= "0"

# SSTATE_SKIP_CREATION ?= "1"

DEBOOTSTRAP ?= "${@'qemu-debootstrap' if d.getVar('BOOTSTRAP_FOR_HOST') == '1' else 'debootstrap'}"
ROOTFSDIR = "${WORKDIR}/rootfs"
APTPREFS = "${WORKDIR}/apt-preferences"
APTSRCS = "${WORKDIR}/apt-sources"
APTSRCS_INIT = "${WORKDIR}/apt-sources-init"
DISTRO_BOOTSTRAP_KEYFILES = ""
THIRD_PARTY_APT_KEYFILES = ""
DEPLOY_ISAR_BOOTSTRAP ?= ""
DISTRO_BOOTSTRAP_BASE_PACKAGES = "locales"
DISTRO_BOOTSTRAP_BASE_PACKAGES:append:gnupg = ",gnupg"
DISTRO_BOOTSTRAP_BASE_PACKAGES:append:https-support = ",ca-certificates"
DISTRO_VARS_PREFIX ?= "${@'HOST_' if d.getVar('BOOTSTRAP_FOR_HOST') == '1' else ''}"
BOOTSTRAP_DISTRO = "${@d.getVar('HOST_DISTRO' if d.getVar('BOOTSTRAP_FOR_HOST') == '1' else 'DISTRO')}"
BOOTSTRAP_BASE_DISTRO = "${@d.getVar('HOST_BASE_DISTRO' if d.getVar('BOOTSTRAP_FOR_HOST') == '1' else 'BASE_DISTRO')}"
FILESEXTRAPATHS:append = ":${BBPATH}"

inherit deb-dl-dir

python () {
    distro_bootstrap_keys = (d.getVar("DISTRO_BOOTSTRAP_KEYS") or "").split()
    third_party_apt_keys = (d.getVar("THIRD_PARTY_APT_KEYS") or "").split()
    topdir = d.getVar("TOPDIR", True)

    # The cached repo key can be both for bootstrapping and apt package
    # installation afterwards. However, debootstrap will include the key into
    # the rootfs automatically thus the right place is distro_bootstrap_keys.

    if bb.utils.to_boolean(d.getVar('ISAR_USE_CACHED_BASE_REPO')):
        own_pub_key = d.getVar("BASE_REPO_KEY")
        if own_pub_key:
            distro_bootstrap_keys += own_pub_key.split()

    for key in distro_bootstrap_keys:
        d.appendVar("SRC_URI", " %s" % key)
        fetcher = bb.fetch2.Fetch([key], d)
        filename = os.path.relpath(fetcher.localpath(key), topdir)
        d.appendVar("DISTRO_BOOTSTRAP_KEYFILES", " ${TOPDIR}/%s" % filename)

    for key in third_party_apt_keys:
        d.appendVar("SRC_URI", " %s" % key)
        fetcher = bb.fetch2.Fetch([key], d)
        filename = os.path.relpath(fetcher.localpath(key), topdir)
        d.appendVar("THIRD_PARTY_APT_KEYFILES", " ${TOPDIR}/%s" % filename)

    distro_apt_sources = d.getVar(d.getVar("DISTRO_VARS_PREFIX") + "DISTRO_APT_SOURCES", True) or ""
    for file in distro_apt_sources.split():
        d.appendVar("SRC_URI", " file://%s" % file)

    distro_apt_preferences = d.getVar(d.getVar("DISTRO_VARS_PREFIX") + "DISTRO_APT_PREFERENCES", True) or ""
    for file in distro_apt_preferences.split():
        d.appendVar("SRC_URI", " file://%s" % file)
}

def aggregate_files(d, file_list, file_out):
    import shutil

    with open(file_out, "wb") as out_fd:
        for entry in file_list:
            entry_real = bb.parse.resolve_file(entry, d)
            with open(entry_real, "rb") as in_fd:
                 shutil.copyfileobj(in_fd, out_fd, 1024*1024*10)
            out_fd.write("\n".encode())

def parse_aptsources_list_line(source_list_line):
    import re

    s = source_list_line.strip()

    if not s or s.startswith("#"):
        return None

    type, s = re.split("\s+", s, maxsplit=1)
    if type not in ["deb", "deb-src"]:
        return None

    options = ""
    options_match = re.match("\[\s*(\S+=\S+(?=\s))*\s*(\S+=\S+)\s*\]\s+", s)
    if options_match:
        options = options_match.group(0).strip()
        s = s[options_match.end():]

    source, s = re.split("\s+", s, maxsplit=1)

    if s.startswith("/"):
        suite = ""
    else:
        suite, s = re.split("\s+", s, maxsplit=1)

    components = " ".join(s.split())

    return [type, options, source, suite, components]

def get_apt_source_mirror(d, aptsources_entry_list):
    import re

    if bb.utils.to_boolean(d.getVar('ISAR_USE_CACHED_BASE_REPO')):
        premirrors = "\S* file://${REPO_BASE_DIR}/${BOOTSTRAP_BASE_DISTRO}\n"
    else:
        premirrors = d.getVar('DISTRO_APT_PREMIRRORS', True) or ""
    mirror_list = [entry.split()
                  for entry in premirrors.split('\\n')
                  if any(entry)]

    for regex, replace in mirror_list:
        match = re.search(regex, aptsources_entry_list[2])

        if match:
            new_aptsources_entry_list = aptsources_entry_list.copy()
            new_aptsources_entry_list[2] = re.sub(regex, replace,
                                                  aptsources_entry_list[2],
                                                  count = 1)
            return new_aptsources_entry_list

    return aptsources_entry_list

def aggregate_aptsources_list(d, file_list, file_out):
    import shutil

    with open(file_out, "wb") as out_fd:
        for entry in file_list:
            entry_real = bb.parse.resolve_file(entry, d)
            with open(entry_real, "r") as in_fd:
                for line in in_fd:
                    parsed = parse_aptsources_list_line(line)
                    if parsed:
                        parsed = get_apt_source_mirror(d, parsed)
                        out_fd.write(" ".join(parsed).encode())
                    else:
                        out_fd.write(line.encode())
                    out_fd.write("\n".encode())
            out_fd.write("\n".encode())

def get_aptsources_list(d):
    import errno
    apt_sources_var = d.getVar("DISTRO_VARS_PREFIX") + "DISTRO_APT_SOURCES"
    list = (d.getVar(apt_sources_var, True) or "").split()
    ret = []
    for p in list:
        try:
            f = bb.parse.resolve_file(p, d)
            ret.append(f)
        except FileNotFoundError as e:
            bb.fatal(os.strerror(errno.ENOENT) + ' "' + p + '"')
    return ret

def generate_distro_sources(d):
    apt_sources_list = get_aptsources_list(d)
    for entry in apt_sources_list:
        with open(entry, "r") as in_fd:
            for line in in_fd:
                parsed = parse_aptsources_list_line(line)
                if parsed:
                    parsed = get_apt_source_mirror(d, parsed)
                    yield parsed

def get_distro_primary_source_entry(d):
    for source in generate_distro_sources(d):
        if source[0] == "deb":
            return source[2:]
    bb.fatal('Invalid apt sources list')

def get_distro_have_https_source(d):
    return any(source[2].startswith("https://") for source in generate_distro_sources(d))

def get_distro_needs_https_support(d):
    if get_distro_have_https_source(d):
        return "https-support"
    else:
        return ""

OVERRIDES:append = ":${@get_distro_needs_https_support(d)}"

def get_distro_needs_gpg_support(d):
    if d.getVar("DISTRO_BOOTSTRAP_KEYS") or \
       d.getVar("THIRD_PARTY_APT_KEYS") or \
       d.getVar("BASE_REPO_KEY"):
        return "gnupg"
    else:
        return ""

OVERRIDES:append = ":${@get_distro_needs_gpg_support(d)}"

def get_distro_source(d):
    return get_distro_primary_source_entry(d)[0]

def get_distro_suite(d):
    return get_distro_primary_source_entry(d)[1]

def get_distro_components_argument(d):
    components = get_distro_primary_source_entry(d)[2]
    if components and components.strip():
        return "--components=" + ",".join(components.split())
    else:
        return ""

APT_KEYS_DIR = "${WORKDIR}/aptkeys"
DISTRO_BOOTSTRAP_KEYRING = "${WORKDIR}/distro-keyring.gpg"

do_generate_keyrings[cleandirs] = "${APT_KEYS_DIR}"
do_generate_keyrings[dirs] = "${DL_DIR}"
do_generate_keyrings[vardeps] += "DISTRO_BOOTSTRAP_KEYS THIRD_PARTY_APT_KEYS"
do_generate_keyrings[network] = "1"
do_generate_keyrings() {
    if [ -n "${@d.getVar("THIRD_PARTY_APT_KEYFILES", True) or ""}" ]; then
        chmod 777 "${APT_KEYS_DIR}"
        for keyfile in ${@d.getVar("THIRD_PARTY_APT_KEYFILES", True)}; do
           cp "$keyfile" "${APT_KEYS_DIR}"/"$(basename "$keyfile")"
        done
    fi
    if [ -n "${@d.getVar("DISTRO_BOOTSTRAP_KEYFILES", True) or ""}" ]; then
        for keyfile in ${@d.getVar("DISTRO_BOOTSTRAP_KEYFILES", True)}; do
           sudo apt-key --keyring "${DISTRO_BOOTSTRAP_KEYRING}" add $keyfile
           cp "$keyfile" "${APT_KEYS_DIR}"/"$(basename "$keyfile")"
        done
    fi
}
addtask generate_keyrings before do_build after do_unpack

do_apt_config_prepare[dirs] = "${WORKDIR}"
do_apt_config_prepare[vardeps] += " \
    APTPREFS \
    ${DISTRO_VARS_PREFIX}DISTRO_APT_PREFERENCES \
    DEBDISTRONAME \
    APTSRCS \
    ${DISTRO_VARS_PREFIX}DISTRO_APT_SOURCES \
    DEPLOY_ISAR_BOOTSTRAP \
    "
python do_apt_config_prepare() {
    apt_preferences_out = d.getVar("APTPREFS", True)
    apt_preferences_list = (
        d.getVar(d.getVar("DISTRO_VARS_PREFIX") + "DISTRO_APT_PREFERENCES", True) or ""
    ).split()
    aggregate_files(d, apt_preferences_list, apt_preferences_out)

    apt_sources_out = d.getVar("APTSRCS", True)
    apt_sources_init_out = d.getVar("APTSRCS_INIT", True)
    apt_sources_list = (
        d.getVar(d.getVar("DISTRO_VARS_PREFIX") + "DISTRO_APT_SOURCES", True) or ""
    ).split()

    aggregate_files(d, apt_sources_list, apt_sources_init_out)
    aggregate_aptsources_list(d, apt_sources_list, apt_sources_out)
}
addtask apt_config_prepare before do_bootstrap after do_unpack

def get_host_release():
    import platform
    rel = platform.release()
    return rel

do_bootstrap[vardeps] += " \
    DISTRO_APT_PREMIRRORS \
    ISAR_ENABLE_COMPAT_ARCH \
    ${DISTRO_VARS_PREFIX}DISTRO_APT_SOURCES \
    "
do_bootstrap[dirs] = "${DEPLOY_DIR_BOOTSTRAP}"
do_bootstrap[depends] = "base-apt:do_cache isar-apt:do_cache_config"
do_bootstrap[network] = "1"

do_bootstrap() {
    if [ "${ISAR_ENABLE_COMPAT_ARCH}" = "1" ]; then
        if [ -z "${COMPAT_DISTRO_ARCH}" ]; then
            bbfatal "${DISTRO_ARCH} does not have a compat arch"
        fi
    fi
    debootstrap_args="--verbose --variant=minbase --include=${DISTRO_BOOTSTRAP_BASE_PACKAGES}"
    if [ -f "${DISTRO_BOOTSTRAP_KEYRING}" ]; then
        debootstrap_args="$debootstrap_args --keyring=${DISTRO_BOOTSTRAP_KEYRING}"
    fi
    if [ "${ISAR_USE_CACHED_BASE_REPO}" = "1" -a -z "${BASE_REPO_KEY}" ]; then
        debootstrap_args="$debootstrap_args --no-check-gpg"
    fi
    E="${@ isar_export_proxies(d)}"
    export BOOTSTRAP_FOR_HOST debootstrap_args E

    sudo rm -rf --one-file-system "${ROOTFSDIR}"
    deb_dl_dir_import "${ROOTFSDIR}" "${BOOTSTRAP_BASE_DISTRO}-${BASE_DISTRO_CODENAME}"

    test -z "${HOST_ARCH}" -o -z "${ROOTFS_ARCH}" -o -z "${DISTRO_ARCH}" && \
        bbwarn "*** ATTENTION *** BOOTSTRAP_FOR_HOST=0, DEBOOTSTRAP=${DEBOOTSTRAP},"\
            "HOST_ARCH=${HOST_ARCH}, ROOTFS_ARCH=${ROOTFS_ARCH}, DISTRO_ARCH=${DISTRO_ARCH}."

    sudo -E -s <<'EOSUDO'
        set -e
        alias wget="wget -c"
        if [ "${BOOTSTRAP_FOR_HOST}" = "0" ]; then
            arch_param="--arch=${DISTRO_ARCH}"
        fi
        if [ "${SHELL}" = "/bin/zsh" ]; then
            ${DEBOOTSTRAP} ${=debootstrap_args} \
                       $arch_param \
                       ${@get_distro_components_argument(d)} \
                       "${@get_distro_suite(d)}" \
                       "${ROOTFSDIR}" \
                       "${@get_distro_source(d)}" \
                       ${DISTRO_DEBOOTSTRAP_SCRIPT}
        else
            ${DEBOOTSTRAP} $debootstrap_args \
                       $arch_param \
                       ${@get_distro_components_argument(d)} \
                       "${@get_distro_suite(d)}" \
                       "${ROOTFSDIR}" \
                       "${@get_distro_source(d)}" \
                       ${DISTRO_DEBOOTSTRAP_SCRIPT}
        fi

        # Install apt config
        rm -f "${ROOTFSDIR}/etc/apt/sources.list"
        mkdir -p "${ROOTFSDIR}/etc/apt/preferences.d"
        install -v -m644 "${APTPREFS}" \
                         "${ROOTFSDIR}/etc/apt/preferences.d/bootstrap"
        mkdir -p "${ROOTFSDIR}/etc/apt/sources.list.d"
        if [ "${ISAR_USE_CACHED_BASE_REPO}" = "1" ]; then
            line="file:///base-apt/${BOOTSTRAP_BASE_DISTRO} ${BASE_DISTRO_CODENAME} main"
            if [ -z "${BASE_REPO_KEY}" ]; then
                line="[trusted=yes] ${line}"
            fi
            echo "deb ${line}" >  "${ROOTFSDIR}/etc/apt/sources.list.d/base-apt.list"
            line="file:///base-apt/${BASE_DISTRO} ${BASE_DISTRO_CODENAME} main"
            if [ -z "${BASE_REPO_KEY}" ]; then
                line="[trusted=yes] ${line}"
            fi
            echo "deb-src ${line}" >>  "${ROOTFSDIR}/etc/apt/sources.list.d/base-apt.list"

            mkdir -p ${ROOTFSDIR}/base-apt
            mount --bind ${REPO_BASE_DIR} ${ROOTFSDIR}/base-apt
        else
            install -v -m644 "${APTSRCS}" \
                             "${ROOTFSDIR}/etc/apt/sources.list.d/bootstrap.list"
        fi
        install -v -m644 "${APTSRCS_INIT}" "${ROOTFSDIR}/etc/apt/sources-list"
        find ${APT_KEYS_DIR}/ -type f | while read keyfile
        do
            MY_GPGHOME="$(chroot "${ROOTFSDIR}" mktemp -d /tmp/gpghomeXXXXXXXXXX)"
            echo "Created temporary directory ${MY_GPGHOME} for gpg-agent"
            export GNUPGHOME="${MY_GPGHOME}"
            APT_KEY_APPEND="--homedir ${MY_GPGHOME}"

            kfn="$(basename $keyfile)"
            cp $keyfile "${ROOTFSDIR}/tmp/$kfn"
            if [ "${SHELL}" = "/bin/zsh" ]; then
                chroot "${ROOTFSDIR}" /usr/bin/gpg-agent --daemon -- /usr/bin/apt-key \
                    --keyring ${THIRD_PARTY_APT_KEYRING} ${=APT_KEY_APPEND} add "/tmp/$kfn"
            else
                chroot "${ROOTFSDIR}" /usr/bin/gpg-agent --daemon -- /usr/bin/apt-key \
                    --keyring ${THIRD_PARTY_APT_KEYRING} ${APT_KEY_APPEND} add "/tmp/$kfn"
            fi
            rm "${ROOTFSDIR}/tmp/$kfn"

            echo "Removing ${MY_GPGHOME}"
            rm -rf "${ROOTFSDIR}${MY_GPGHOME}"
        done

        # Set locale
        install -v -m644 "${WORKDIR}/locale" "${ROOTFSDIR}/etc/locale"

        sed -i '/en_US.UTF-8 UTF-8/s/^#//g' "${ROOTFSDIR}/etc/locale.gen"
        chroot "${ROOTFSDIR}" /usr/sbin/locale-gen

        # setup chroot
        install -v -m755 "${WORKDIR}/chroot-setup.sh" "${ROOTFSDIR}/chroot-setup.sh"
        "${ROOTFSDIR}/chroot-setup.sh" "setup" "${ROOTFSDIR}"

        # update APT
        mount -o bind,private /dev ${ROOTFSDIR}/dev
        mount --bind /dev/pts ${ROOTFSDIR}/dev/pts
        mount -t tmpfs none "${ROOTFSDIR}/dev/shm"
        mount -t proc none ${ROOTFSDIR}/proc
        mount --rbind /sys ${ROOTFSDIR}/sys
        mount --make-rslave ${ROOTFSDIR}/sys

        export DEBIAN_FRONTEND=noninteractive

        if [ "${BOOTSTRAP_FOR_HOST}" = "1" ]; then
            chroot "${ROOTFSDIR}" /usr/bin/dpkg --add-architecture ${DISTRO_ARCH}
        fi

        if [ "${ISAR_ENABLE_COMPAT_ARCH}" = "1" ]; then
            chroot "${ROOTFSDIR}" /usr/bin/dpkg --add-architecture ${COMPAT_DISTRO_ARCH}
        fi

        chroot "${ROOTFSDIR}" /usr/bin/apt-get update -y \
                                -o APT::Update::Error-Mode=any
        chroot "${ROOTFSDIR}" /usr/bin/apt-get install -y -f
        chroot "${ROOTFSDIR}" /usr/bin/apt-get dist-upgrade -y \
                                -o Debug::pkgProblemResolver=yes

        umount -l "${ROOTFSDIR}/dev/shm"
        umount -l "${ROOTFSDIR}/dev/pts"
        umount -l "${ROOTFSDIR}/dev"
        umount -l "${ROOTFSDIR}/proc"
        umount -l "${ROOTFSDIR}/sys"
        umount -l "${ROOTFSDIR}/base-apt" || true

        # Finalize debootstrap by setting the link in deploy
        ln -Tfsr "${ROOTFSDIR}" "${DEPLOY_ISAR_BOOTSTRAP}"
EOSUDO
    deb_dl_dir_export "${ROOTFSDIR}" "${BOOTSTRAP_BASE_DISTRO}-${BASE_DISTRO_CODENAME}"

    sudo -E chroot "${ROOTFSDIR}" /usr/bin/apt-get -y clean
}

addtask bootstrap before do_build after do_generate_keyrings

SSTATETASKS += "do_bootstrap"
SSTATECREATEFUNCS += "bootstrap_sstate_prepare"
SSTATEPOSTINSTFUNCS += "bootstrap_sstate_finalize"

bootstrap_sstate_prepare() {
    # this runs in SSTATE_BUILDDIR, which will be deleted automatically
    sudo tar --one-file-system --exclude="var/log/*" --exclude="var/cache/*" --exclude="var/backups/*" \
        --exclude="var/tmp/*" --exclude="var/crash/*" --exclude="var/spool/*" --exclude="var/lib/apt/*" \
        --exclude-caches --exclude-backups -C $(dirname "${ROOTFSDIR}") -cpSf bootstrap.tar $(basename "${ROOTFSDIR}")
    sudo chown $(id -u):$(id -g) bootstrap.tar
}

bootstrap_sstate_finalize() {
    # this runs in SSTATE_INSTDIR
    # - after building the bootstrap, the tar won't be there, but we also don't need to unpack
    # - after restoring from cache, there will be a tar which we unpack and then delete
    if [ -f bootstrap.tar ]; then
        sudo tar -C $(dirname "${ROOTFSDIR}") -xpf bootstrap.tar
        sudo ln -Tfsr "${ROOTFSDIR}" "${DEPLOY_ISAR_BOOTSTRAP}"
        rm bootstrap.tar
    fi
}

python do_bootstrap_setscene() {
    sstate_setscene(d)
}

addtask do_bootstrap_setscene
do_bootstrap_setscene[dirs] = "${DEPLOY_DIR_BOOTSTRAP}"

CLEANFUNCS = "clean_deploy"
clean_deploy() {
    rm -f "${DEPLOY_ISAR_BOOTSTRAP}"
}
