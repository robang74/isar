# This software is a part of ISAR.
# Copyright (C) Siemens AG, 2019
#
# SPDX-License-Identifier: MIT
#
# This file extends the image.bbclass to supply tools for futher imager functions

inherit sbuild

IMAGER_INSTALL ??= ""
IMAGER_BUILD_DEPS ??= ""
DEPENDS += "${IMAGER_BUILD_DEPS}"

ISAR_CROSS_COMPILE ?= "0"

IMAGER_SCHROOT_SESSION_ID = "isar-imager-${SCHROOT_USER}-${PN}-${MACHINE}-${ISAR_BUILD_UUID}"

do_install_imager_deps[depends] = "${SCHROOT_DEP} isar-apt:do_cache_config"
do_install_imager_deps[deptask] = "do_deploy_deb"
do_install_imager_deps[lockfiles] += "${REPO_ISAR_DIR}/isar.lock"
do_install_imager_deps() {
    if [ -z "${@d.getVar("IMAGER_INSTALL", True).strip()}" ]; then
        exit
    fi

    distro="${BASE_DISTRO}-${BASE_DISTRO_CODENAME}"
    if [ ${ISAR_CROSS_COMPILE} -eq 1 ]; then
        distro="${HOST_BASE_DISTRO}-${BASE_DISTRO_CODENAME}"
    fi
    session="${SCHROOT_OVERLAY_DIR}/${IMAGER_SCHROOT_SESSION_ID}"

    E="${@ isar_export_proxies(d)}"
    deb_dl_dir_import ${session}/upper ${distro}

    schroot -r -c ${IMAGER_SCHROOT_SESSION_ID} -d / -u root -- sh -c ' \
        apt-get -y update
        apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends \
            --allow-unauthenticated --allow-downgrades -y install \
            ${IMAGER_INSTALL}'

    deb_dl_dir_export ${session}/upper ${distro}

    schroot -r -c ${IMAGER_SCHROOT_SESSION_ID} -d / -u root -- sh -c ' \
        apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y \
            --allow-unauthenticated --allow-downgrades install \
            ${IMAGER_INSTALL}
        apt-get -y clean'

    sudo -E chroot ${SCHROOT_DIR} /usr/bin/apt-get -y clean
}
addtask install_imager_deps before do_image_tools after do_start_imager_session

SCHROOT_MOUNTS = "${WORKDIR}:${PP_WORK} ${IMAGE_ROOTFS}:${PP_ROOTFS} ${DEPLOY_DIR_IMAGE}:${PP_DEPLOY}"

do_start_imager_session[dirs] = "${WORKDIR} ${IMAGE_ROOTFS} ${DEPLOY_DIR_IMAGE}"
do_start_imager_session[depends] = "${SCHROOT_DEP} isar-apt:do_cache_config"
do_start_imager_session[nostamp] = "1"
do_start_imager_session[network] = "${TASK_USE_SUDO}"
python do_start_imager_session() {
    import subprocess
    attempts=0
    while attempts < 2:
        attempts+=1
        bb.build.exec_func("schroot_create_configs", d)
        bb.build.exec_func("insert_mounts", d)
        sbuild_chroot = d.getVar("SBUILD_CHROOT", True)
        session_id = d.getVar("IMAGER_SCHROOT_SESSION_ID", True)
        try:
            bb.debug(2, "Opening schroot session %s" % sbuild_chroot)
            id = subprocess.run("schroot -d / -b -c %s -n %s -- printenv -0 SCHROOT_ALIAS_NAME"
                % (sbuild_chroot, session_id), shell=True, check=True)
            attempts=2
        except subprocess.CalledProcessError as err:
            try:
                bb.debug(2, "Reusing schroot session %s" % sbuild_chroot)
                id = subprocess.run("schroot -d / -r -c %s -- printenv -0 SCHROOT_ALIAS_NAME"
                    % session_id, shell=True, check=True)
            except subprocess.CalledProcessError as err:
                bb.debug(2, "Closing schroot session %s (%s)" % (sbuild_chroot, session_id))
                bb.build.exec_func("stop_schroot_session", d)
        if 'id' in locals():
            d.setVar("SBUILD_CHROOT", id)
}
addtask start_imager_session before do_stop_imager_session after do_rootfs_finalize

do_stop_imager_session[depends] = "${SCHROOT_DEP}"
do_stop_imager_session[nostamp] = "1"
do_stop_imager_session[network] = "${TASK_USE_SUDO}"
python do_stop_imager_session() {
    bb.build.exec_func("stop_schroot_session", d)
}
addtask stop_imager_session before do_deploy after do_image

imager_run() {
    imager_cleanup() {
        if id="$(schroot -d / -r -c ${IMAGER_SCHROOT_SESSION_ID} -- printenv -0 SCHROOT_ALIAS_NAME)"; then
            schroot -e -c ${IMAGER_SCHROOT_SESSION_ID}
            remove_mounts $id
            schroot_delete_configs $id
        fi
    }
    trap 'exit 1' INT HUP QUIT TERM ALRM USR1
    trap 'imager_cleanup' EXIT
    schroot -r -c ${IMAGER_SCHROOT_SESSION_ID} "$@"
}
