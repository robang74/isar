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
do_install_imager_deps[network] = "1"
do_install_imager_deps() {
    if [ -z "${@d.getVar("IMAGER_INSTALL", True).strip()}" ]; then
        exit
    fi

    distro="${BASE_DISTRO}-${BASE_DISTRO_CODENAME}"
    if [ ${ISAR_CROSS_COMPILE} -eq 1 ]; then
        distro="${HOST_BASE_DISTRO}-${BASE_DISTRO_CODENAME}"
    fi

    E="${@ isar_export_proxies(d)}"
    deb_dl_dir_import "${SCHROOT_DIR}" "${distro}"

    schroot -r -c ${IMAGER_SCHROOT_SESSION_ID} -d / -u root -- sh -c ' \
        apt-get update \
            -o Dir::Etc::SourceList="sources.list.d/isar-apt.list" \
            -o Dir::Etc::SourceParts="-" \
            -o APT::Get::List-Cleanup="0"
        apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y \
            --allow-unauthenticated --allow-downgrades --download-only install \
            ${IMAGER_INSTALL}'

    deb_dl_dir_export "${SCHROOT_DIR}" "${distro}"

    schroot -r -c ${IMAGER_SCHROOT_SESSION_ID} -d / -u root -- sh -c ' \
        apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y \
            --allow-unauthenticated --allow-downgrades install \
            ${IMAGER_INSTALL}'

    sudo -E chroot "${SCHROOT_DIR}" /usr/bin/apt-get -y clean
}
addtask install_imager_deps before do_image_tools after do_start_imager_session

SCHROOT_MOUNTS = "${WORKDIR}:${PP_WORK} ${IMAGE_ROOTFS}:${PP_ROOTFS} ${DEPLOY_DIR_IMAGE}:${PP_DEPLOY}"

do_start_imager_session[dirs] = "${WORKDIR} ${IMAGE_ROOTFS} ${DEPLOY_DIR_IMAGE}"
do_start_imager_session[depends] = "${SCHROOT_DEP} isar-apt:do_cache_config"
do_start_imager_session[nostamp] = "1"
do_start_imager_session[network] = "${TASK_USE_SUDO}"
python do_start_imager_session() {
    import subprocess

    remove = 0
    attempts = 0
    while attempts < 2:
        attempts += 1
        sbuild_chroot = d.getVar("SBUILD_CHROOT", True)
        session_id = d.getVar("IMAGER_SCHROOT_SESSION_ID", True)
        bb.build.exec_func("schroot_create_configs", d)
        bb.build.exec_func("insert_mounts", d)
        bb.debug(2, "Opening schroot session %s" % sbuild_chroot)
        if not subprocess.run("schroot -b -c %s -n %s" % (sbuild_chroot, session_id), shell=True).returncode:
            attempts = 1
            break
        bb.debug(2, "Reusing schroot session %s" % sbuild_chroot)
        if not subprocess.run("schroot --recover-session -c %s" % session_id, shell=True).returncode:
            attempts = 1
            break
        udir = d.getVar("SCHROOT_OVERLAY_DIR", True)
        bb.debug(2, "Closing schroot session %s (%s)" % (sbuild_chroot, session_id))
        if subprocess.run("schroot -fe -c %s" % session_id, shell=True).returncode:
            remove = 1
        bb.build.exec_func("remove_mounts", d)
        bb.build.exec_func("schroot_delete_configs", d)
        if remove:
            bb.debug(2, "Removing session dir: %s/%s" % (udir, session_id))
            subprocess.run("sudo rm -rf --one-file-system %s/%s /var/lib/schroot/session/%s" % (udir, session_id, session_id), shell=True)

    if(attempts > 1):
        bb.fatal("Could not create schroot session: %s" % session_id)
    d.setVar("SCHROOT_OPEN_SESSION_ID", session_id)
    return 0
}
addtask start_imager_session before do_stop_imager_session after do_rootfs_finalize

do_stop_imager_session[depends] = "${SCHROOT_DEP}"
do_stop_imager_session[nostamp] = "1"
do_stop_imager_session[network] = "${TASK_USE_SUDO}"
python do_stop_imager_session() {
    import subprocess
    session_id = d.getVar("IMAGER_SCHROOT_SESSION_ID", True)
    try:
        id = subprocess.run("schroot -d / -r -c %s -- printenv -0 SCHROOT_ALIAS_NAME" % session_id,
                            shell=True, check=True, stdout=subprocess.PIPE).stdout.decode('utf-8')
    except subprocess.CalledProcessError as err:
        bb.error("Could not close schroot session %s: %s" % (session_id, err.output.decode('utf-8')) if err.output else "")
    finally:
        bb.debug(2, "Closing schroot stop session %s (%s)" % (session_id, id))
        subprocess.run("schroot -fe -c %s" % session_id, shell=True)
        if 'id' in locals():
            d.setVar("SBUILD_CHROOT", id)
            bb.build.exec_func("remove_mounts", d)
            bb.build.exec_func("schroot_delete_configs", d)
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
