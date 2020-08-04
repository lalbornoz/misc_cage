#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# References:
# Wed, 20 May 2020 15:42:45 +0200 [1] Python APT Library — python-apt 2.1.3 documentation <https://apt-team.pages.debian.net/python-apt/library/index.html>
#

import apt, apt_pkg
import argparse, hashlib, itertools, json, logging, os, sys, time

# {{{ class AptUpgradesLogger(object)
class AptUpgradesLogger(object):
    # {{{ class Formatter(logging.Formatter)
    class Formatter(logging.Formatter):
        ansiColours = {"CRITICAL":91, "ERROR":91, "WARNING":31, "INFO":93, "VERBOSE":96, "DEBUG":35}

        def format(self, record):
            message = super().format(record)
            if self.ansiEnabled:
                return "\x1b[{}m{}\x1b[0m".format(self.ansiColours[record.levelname], message)
            else:
                return message
        def formatTime(self, record, datefmt="%Y-%b-%d %H:%M:%S"):
            return time.strftime(datefmt).upper()
        def __init__(self, fmt="%(asctime)-20s %(message)s", datefmt="%Y-%b-%d %H:%M:%S", style="%"):
            super().__init__(fmt, datefmt, style); self.ansiEnabled = sys.stdout.isatty();
    # }}}
    VERBOSE = 15

    def verbose(self, message, *args, **kwargs):
        if self.logger.isEnabledFor(self.VERBOSE):
            self.logger._log(self.VERBOSE, message, args, **kwargs)

    def __init__(self, initialLevel=logging.INFO, name="apt-python"):
        consoleHandler = logging.StreamHandler(sys.stdout)
        consoleHandler.setFormatter(self.Formatter())
        logging.addLevelName(self.VERBOSE, "VERBOSE")
        logging.basicConfig(handlers=(consoleHandler,))
        self.logger = logging.getLogger(name); self.logger.verbose = self.verbose;
        self.logger.setLevel(initialLevel)
# }}}

class AptUpgrades(object):
    """APT package upgrades check class"""
    # {{{ Class variables
    cacheNewCountMax = 3
    cacheNewFileName = "~/.cache/AptUpgrades.json"
    # }}}

    # {{{ def _aptLock(self)
    def _aptLock(self):
        self.cache, self.depCache, self.pkgCache, self.pkgManager = None, None, None, None
        try:
            self.logger.logger.verbose("Locking the global pkgsystem."); apt_pkg.pkgsystem_lock(); cache = apt.Cache();
            self.logger.logger.verbose("Locking the global pkgsystem."); apt_pkg.pkgsystem_lock();
            self.logger.logger.verbose("Updating cache..."); cache.update(); self.logger.logger.verbose("Opening cache..."); cache.open(None);
            pkgCache = apt_pkg.Cache(progress=None); depCache = apt_pkg.DepCache(pkgCache); pkgManager = apt_pkg.PackageManager(depCache);
            self.cache, self.depCache, self.pkgCache, self.pkgManager = cache, depCache, pkgCache, pkgManager
            return True
        except Exception as e:
            self.logger.logger.error(e)
            return False
    # }}}
    # {{{ def _aptUnlock(self)
    def _aptUnlock(self):
        try:
            self.logger.logger.verbose("Unlocking the global pkgsystem."); apt_pkg.pkgsystem_unlock()
            self.cache, self.pkgCache = None, None
            return True
        except Exception as e:
            self.logger.logger.error(e)
            return False
    # }}}
    # {{{ def _isReportNew(self, report)
    def _isReportNew(self, report):
        if self.args.new:
            reportHash = hashlib.sha256(report.encode()).hexdigest()
            if os.path.exists(self.cacheNewFileName):
                with open(self.cacheNewFileName, "r") as fileObject:
                    cacheNew = json.load(fileObject)
                if cacheNew["hash"] == reportHash:
                    cacheNew["count"] += 1
                    printFlag = (cacheNew["count"] <= self.cacheNewCountMax)
                else:
                    cacheNew, printFlag = {"count":1, "hash":reportHash}, True
            else:
                cacheNew, printFlag = {"count":1, "hash":reportHash}, True
        else:
            return True
        if printFlag:
            with open(self.cacheNewFileName, "w") as fileObject:
                json.dump(cacheNew, fileObject)
        return printFlag
    # }}}}
    # {{{ def _printReport(self, downloaded, names, reverseDepends, serviceUnits, serviceUnitsReverse, file=sys.stdout)
    def _printReport(self, downloaded, names, reverseDepends, serviceUnits, serviceUnitsReverse, file=sys.stdout):
        report = '''\
APT package upgrade report
==========================

'''
        names_, reverseDepends_ = ", ".join(sorted(tuple(set(names)))), ", ".join(sorted(tuple(set(reverseDepends))))
        report += '''The following packages can be upgraded{}:
{}'''.format("" if not downloaded else " and have been downloaded", ", ".join(sorted(tuple(set(names)))))
        if (names_ != reverseDepends_) and len(reverseDepends_):
            report += '''

The following reverse dependencies, sans library packages, may be affected:
{}'''.format(", ".join(sorted(tuple(set(reverseDepends)))))
        serviceUnits_ = "\n".join(sorted(["{0:48s}[owned by {1}]".format(*u) for u in tuple(set(serviceUnitsReverse))]))
        serviceUnitsReverse_ = "\n".join(sorted(["{0:48s}[owned by {1}]".format(*u) for u in tuple(set(serviceUnitsReverse))]))
        if len(serviceUnits_) and len(serviceUnitsReverse_) and (serviceUnits_ == serviceUnitsReverse_):
            report += '''

This upgrade and its reverse dependencies, sans library packages, encompass the following systemd service units:
{}'''.format(serviceUnits_)
        else:
            if len(serviceUnits_):
                report += '''

This upgrade encompasses the following systemd service units:
{}'''.format(serviceUnits_)
            if len(serviceUnitsReverse):
                report += '''

The reverse dependencies, sans library packages, listed above encompass the following systemd service units:
{}'''.format(serviceUnitsReverse_)
        if self._isReportNew(report):
            print(report, file=file)
    # }}}}

    # {{{ def filterInstalled(self, pkg)
    def filterInstalled(self, pkg):
        return self.pkgCache[pkg.name].selected_state == apt_pkg.SELSTATE_INSTALL
    # }}}
    # {{{ def filterUpgradable(self, pkg)
    def filterUpgradable(self, pkg):
        return self.cache[pkg.name].is_upgradable
    # }}}
    # {{{ def getDepends(self, pkg, depends=(), dependsCache=(), predicate=None)
    def getDepends(self, pkg, depends=(), dependsCache=(()), predicate=None):
        depends, pkgCurrentVer = (), self.pkgCache[pkg.name].current_ver
        if pkgCurrentVer is not None:
            for pkgDependType in pkgCurrentVer.depends_list.keys():
                for pkgDepend in pkgCurrentVer.depends_list[pkgDependType]:
                    for pkgDependOr in (p.target_pkg for p in pkgDepend if not p.target_pkg.name in dependsCache):
                        dependsCache += (pkgDependOr.name,)
                        if predicate is not None and not predicate(pkgDependOr):
                            continue
                        else:
                            depends += (pkgDependOr, *self.getDepends(pkgDependOr, depends, dependsCache, predicate),)
        return tuple(set([p for p in depends]))
    # }}}
    # {{{ def getReverseDepends(self, pkg, predicate=None)
    def getReverseDepends(self, pkg, predicate=None):
        rdepends, rdepends_ = filter(lambda p: self.filterInstalled(p.parent_pkg), self.pkgCache[pkg.name].rev_depends_list), ()
        for rdepend in [p.parent_pkg for p in rdepends if not p.parent_pkg.name in rdepends_]:
            if predicate is not None and not predicate(rdepend):
                continue
            else:
                rdepends_ += (rdepend,)
        return tuple(set(rdepends_))
    # }}}
    # {{{ def getServices(self, pkgList)
    def getServices(self, pkgList):
        services = ()
        for pkg in pkgList:
            pkgNameList = pkg.name.split("-")
            def getServicesPredicate(pkg_):
                return len(os.path.commonprefix((pkgNameList, pkg_.name.split("-"),))) and self.filterInstalled(pkg_)
            for pkg_ in (*self.getDepends(pkg, predicate=getServicesPredicate), pkg,):
                services_ = self.getServiceUnitFiles(pkg_)
                if len(services_):
                    services += (services_,)
        return services
    # }}}
    # {{{ def getServiceUnitFiles(self, pkg)
    def getServiceUnitFiles(self, pkg):
        serviceUnitFiles = ()
        for installedFile in self.cache[pkg.name].installed_files:
            if installedFile.startswith("/lib/systemd/system/") and installedFile.endswith(".service"):
                serviceUnitFiles += (installedFile, pkg.name,)
        return serviceUnitFiles
    # }}}

    # {{{ def main(self)
    def main(self):
        return 0 if self.synchronise() else 1
    # }}}
    # {{{ def synchronise(self)
    def synchronise(self):
        if self._aptLock():
            if self.args.test:
                try:
                    pkgList = [self.cache[name] for name in self.args.test.split(",")]
                except KeyError as e:
                    self.logger.logger.error(e); return False;
            else:
                pkgList = list(filter(lambda p: self.filterInstalled(p) and self.filterUpgradable(p), self.cache))
            if len(pkgList):
                pkgDownloaded, pkgListNames, pkgListReverseDepends, pkgListServiceUnits, pkgListServiceUnitsReverse = False, [], [], [], []
                for pkg in pkgList:
                    pkgListNames += [pkg.name]
                    pkgReverseDepends = self.getReverseDepends(pkg, lambda p: not p.name.startswith("lib"))
                    pkgListServiceUnits += self.getServices([pkg])
                    pkgListServiceUnitsReverse += self.getServices(pkgReverseDepends)
                    pkgListReverseDepends += [p.name for p in pkgReverseDepends]
                if self.args.download:
                    pkgAcquire, pkgSourceList = apt_pkg.Acquire(), apt_pkg.SourceList()
                    self.logger.logger.verbose("Reading main source lists...")
                    pkgSourceList.read_main_list()
                    self.depCache.upgrade()
                    self.logger.logger.verbose("Downloading archives...")
                    pkgDownloaded = self.pkgManager.get_archives(pkgAcquire, pkgSourceList, apt_pkg.PackageRecords(self.pkgCache))
                    pkgAcquire.run()
                self._printReport(pkgDownloaded, pkgListNames, pkgListReverseDepends, pkgListServiceUnits, pkgListServiceUnitsReverse)
            self._aptUnlock()
            return True
        else:
            return False
    # }}}

    def __init__(self):
        self.args, self.cache, self.logger, self.pkgCache = None, None, None, None
        parser = argparse.ArgumentParser(description="")
        parser.add_argument("-d", "--download", action="store_true", default=False, dest="download")
        parser.add_argument("-N", "--new", action="store_true", default=False, dest="new")
        parser.add_argument("-t", "--test", action="store", default=False, dest="test")
        parser.add_argument("-v", "--verbose", action="store_true", default=False, dest="verbose")
        self.args = parser.parse_args()
        self.logger = AptUpgradesLogger(initialLevel=AptUpgradesLogger.VERBOSE if self.args.verbose else logging.INFO)
        self.cacheNewFileName = os.path.abspath(os.path.expanduser(self.cacheNewFileName))
        if not os.path.exists(os.path.dirname(self.cacheNewFileName)):
            os.makedirs(os.path.dirname(self.cacheNewFileName))

if __name__ == "__main__":
    exit(AptUpgrades().main())
