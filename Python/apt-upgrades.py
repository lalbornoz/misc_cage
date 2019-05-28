#!/usr/bin/env python
# -*- coding: utf-8 -*-
# References:
# Sat, 28 May 2016 12:27:48 +0200 [1] Overview — python-apt 1.1.0~beta2 documentation <https://apt.alioth.debian.org/python-apt-doc/>
#

from __future__ import print_function
import apt
import apt.debfile
import apt_pkg
import argparse
import logging
import os.path
import sys
import time

def pkg_filter_installed(pkg_cache, pkg):
    return pkg_cache[pkg.name].selected_state == apt_pkg.SELSTATE_INSTALL
def pkg_filter_upgradable(cache, pkg):
    return cache[pkg.name].is_upgradable
def pkg_has_service_unit_file(cache, pkg):
    for _pname in cache[pkg.name].installed_files:
        if(_pname.startswith("/lib/systemd/system/")
                and _pname.endswith(".service")):
            return True
    return False
def plural_suffix_noun(n):
    return ("" if n == 1 else "s")
def plural_suffix_verb(n):
    return ("s" if n == 1 else "")

def main():
    logging.basicConfig(format="%(asctime)-15s %(message)s")
    _logger = logging.getLogger("apt-python")
    _parser = argparse.ArgumentParser(description="")
    _parser.add_argument("-n", "--dry-run", action="store_true",
        default=False, dest="dry_run")
    _parser.add_argument("-d", "--debug", action="store_true",
        default=False, dest="debug")
    _parser.add_argument("-t", "--test", action="store",
        default=False, dest="test")
    _parser.add_argument("-v", "--verbose", action="store_true",
        default=False, dest="verbose")
    _args = _parser.parse_args()
    if _args.debug:
        _logger.setLevel(logging.DEBUG)
    else:
        _logger.setLevel(logging.INFO)
    _logger.debug("Locking the global pkgsystem.")

    apt_pkg.pkgsystem_lock()
    _cache = apt.Cache()
    _logger.debug("Locking the global pkgsystem.")
    apt_pkg.pkgsystem_lock()    # XXX locking twice is necessary as python-apt is fucking broken garbage software
    _logger.info("Updating cache.")
    _cache.update()
    _logger.info("Opening cache.")
    _cache.open(None)
    _pkg_cache = apt_pkg.Cache(progress=None)
    _pkg_dep_cache = apt_pkg.DepCache(_pkg_cache)
    _pkg_pkg_mgr = apt_pkg.PackageManager(_pkg_dep_cache)
    if _args.debug:
        _pkg_acquire = apt_pkg.Acquire(apt.progress.text.AcquireProgress())
    else:
        _pkg_acquire = apt_pkg.Acquire()
    _pkg_source_list = apt_pkg.SourceList()
    _logger.info("Reading main source lists.")
    _pkg_source_list.read_main_list()

    _npkg_upgrade = 0
    if _args.test:
        _pkg_list = [_cache[_args.test]]
    else:
        _pkg_list = filter(lambda p: pkg_filter_installed(_pkg_cache, p)
                and pkg_filter_upgradable(_cache, p), _cache)
    for pkg in _pkg_list:
        _logger.info(pkg.name + " has an upgrade available.")

        _pkg_rdep_names = []
        for _pkg_rdep in filter(lambda p: pkg_filter_installed(_pkg_cache, p.parent_pkg),
                _pkg_cache[pkg.name].rev_depends_list):
            if _pkg_rdep.parent_pkg.name in _pkg_rdep_names:
                continue
            else:
                _pkg_rdep_names.append(_pkg_rdep.parent_pkg.name)
        if len(_pkg_rdep_names):
            _logger.info("The following package" + plural_suffix_noun(_pkg_rdep_names)
                + " depend" + plural_suffix_verb(_pkg_rdep_names) + " on this package:")
            for _pkg_rdep_name in _pkg_rdep_names:
                if(pkg_has_service_unit_file(_cache, _pkg_cache[_pkg_rdep_name])):
                    _logger.info("  " + _pkg_rdep_name + " [SERVICE]");
                else:
                    _logger.info("  " + _pkg_rdep_name);

        _logger.debug("Marking " + pkg.name + " for installation.")
        _pkg_dep_cache.mark_install(_pkg_cache[pkg.name])
        _npkg_upgrade += 1

    if ((_npkg_upgrade == 0) and (_args.debug or _args.verbose)
    or  (_npkg_upgrade > 0)):
        if _args.debug:
            _logger.info(str(_npkg_upgrade) + " package" + plural_suffix_noun(_npkg_upgrade)
                + " to upgrade.")
        else:
            _logger.info(str(_npkg_upgrade) + " package" + plural_suffix_noun(_npkg_upgrade)
                + " to upgrade.")
    if (not _args.dry_run) and (_npkg_upgrade > 0):
        _logger.debug("Invoking _pkg_dep_cache.upgrade().")
        _pkg_dep_cache.upgrade()
        _logger.debug("Invoking _pkg_pkg_mgr.get_archives().")
        _pkg_pkg_mgr.get_archives(_pkg_acquire, _pkg_source_list,
            apt_pkg.PackageRecords(_pkg_cache))
        _logger.debug("Invoking _pkg_acquire.run().");
        _pkg_acquire.run()
        _logger.debug("Invoked _pkg_acquire.run().");
    apt_pkg.pkgsystem_unlock()
    _logger.debug("Exiting.");
if __name__ == "__main__":
    main()
