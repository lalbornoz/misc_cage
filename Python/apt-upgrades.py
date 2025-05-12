#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Tested w/ python3-apt v1.6.5ubuntu0.4 on Ubuntu 18.04.5 LTS.
#
# References:
#
# Fri, 11 Dec 2020 18:45:40 +0100 [1] Python APT Library — python-apt 2.1.7 documentation <https://apt-team.pages.debian.net/python-apt/library/index.html>
#
# TODO: improve logging, error handling, reporting
# TODO: -n flag
#

import apt, apt_pkg
import argparse, glob, hashlib, json, logging, tempfile
import io, os, re, subprocess, sys, time, traceback
from types import FunctionType, MethodType
from typing import List, Tuple, Union

loggerName = "apt-python"

# {{{ class TransBool(object)(initialState: bool = "False", initialTransition: bool = "False"
class TransBool(object):
    def __bool__(self):
        return self.state

    def set(self, state: bool, transition: bool = None):
        if transition or (self.state != state):
            self.transition = (True if transition is None else transition)
            self.state = state

    def __init__(self, initialState: bool = False, initialTransition: bool = False):
        self.state, self.transition = initialState, initialTransition
# }}}

# {{{ class AptState(object)(loggerName: str = loggerName)
class AptState(object):
    """APT state"""
    # {{{ Class variables
    hasInit = False
    halfInstalledFilter = (
        apt_pkg.CURSTATE_HALF_CONFIGURED,
        apt_pkg.CURSTATE_HALF_INSTALLED,
        apt_pkg.CURSTATE_UNPACKED,
    )
    # }}}
    # {{{ def _lock(self)
    def _lock(self):
        self.logger.verbose("Locking the global pkgsystem.")
        apt_pkg.pkgsystem_lock(); self.locked = True
    # }}}
    # {{{ def _unlock(self)
    def _unlock(self):
        self.logger.verbose("Unlocking the global pkgsystem.")
        apt_pkg.pkgsystem_unlock(); self.locked = False
    # }}}

    # {{{ def filterAutoRemovable(self, pkg: apt_pkg.Package) -> bool
    def filterAutoRemovable(self, pkg: apt_pkg.Package) -> bool:
        return (self.cache[pkg.name].is_auto_removable if pkg.name in self.cache else False)
    # }}}
    # {{{ def filterHalfInstalled(self, pkg: apt_pkg.Package) -> bool
    def filterHalfInstalled(self, pkg: apt_pkg.Package) -> bool:
        return ((self.pkgCache[pkg.name].current_state in self.halfInstalledFilter)
                if pkg.name in self.pkgCache else False)
    # }}}
    # {{{ def filterInstalled(self, pkg: apt_pkg.Package) -> bool
    def filterInstalled(self, pkg: apt_pkg.Package) -> bool:
        return ((self.pkgCache[pkg.name].current_state in (*self.halfInstalledFilter, apt_pkg.CURSTATE_INSTALLED))
                if pkg.name in self.pkgCache else False)
    # }}}
    # {{{ def filterPhasing(self, pkg: apt_pkg.Package) -> bool
    def filterPhasing(self, pkg: apt_pkg.Package) -> bool:
        return (self.depCache.phasing_applied(pkg))
    # }}}
    # {{{ def filterUpgradable(self, pkg: apt_pkg.Package) -> bool
    def filterUpgradable(self, pkg: apt_pkg.Package) -> bool:
        return (self.cache[pkg.name].is_upgradable if pkg.name in self.cache else False)
    # }}}
    # {{{ def markPackages(self, operations, pkgList: List[apt_pkg.Package])
    def markPackages(self, operations, pkgList: List[apt_pkg.Package]):
        for pkg in pkgList:
            self.depCache.mark_install(pkg); self.pkgList[pkg.name] = AptPackage(operations, pkg, self)
    # }}}
    # {{{ def reset(self)
    def reset(self):
        self.cache, self.depCache, self.pkgCache, self.pkgList = None, None, None, {}
    # }}}
    # {{{ def update(self, createCache: bool = False)
    def update(self, createCache: bool = False):
        if createCache:
            self.cache = apt.Cache()
        self.logger.verbose("Updating cache..."); self.cache.update()
        self.logger.verbose("Opening cache..."); self.cache.open(None)
        self.pkgCache = apt_pkg.Cache(progress=None)
        self.depCache = apt_pkg.DepCache(self.pkgCache)
        self.pkgManager = apt_pkg.PackageManager(self.depCache)
        self.pkgList = {}
    # }}}

    # {{{ def __enter__(self)
    def __enter__(self):
        if not self.hasInit:
            apt_pkg.init(); self.hasInit = True
        self._lock(); self.update(createCache=True)
        return self
    # }}}
    # {{{ def __exit__(self, exc_type: type, exc_value: Exception, traceback: traceback)
    def __exit__(self, exc_type: type, exc_value: Exception, traceback: traceback):
        if self.locked:
            self._unlock()
        self.reset()
    # }}}

    def __init__(self, loggerName: str = loggerName):
        self.locked, self.logger = False, logging.getLogger(loggerName); self.reset()
# }}}
# {{{ class AptOperations(object)(state: AptState, checkPolicyDontStartServices: bool = True, loggerName: str = loggerName)
class AptOperations(object):
    """APT state operators"""
    # {{{ Class variables
    initScriptPolicyLayerHelperFileName = "/usr/sbin/policy-rc.d"
    # }}}
    # {{{ def operation(fn: FunctionType)
    def operation(fn: FunctionType):
        def fn_(*args, **kwargs):
            rv = fn(*args, **kwargs); fn_.state = rv; return rv
        setattr(fn_, "state", None)
        return fn_
    # }}}

    # {{{ def autoRemove(self, purge: bool = True)
    @operation
    def autoRemove(self, purge: bool = True):
        pkgList, rc, output = tuple(filter(lambda pkg:
                self.state.filterAutoRemovable(pkg), self.state.pkgCache.packages)), True, []
        if len(pkgList):
            self.state.cache.clear()
            for pkg in pkgList:
                self.logger.verbose("Marked package {} for deletion w/ purge=True.".format(pkg))
                output += ["Marked package {} for deletion w/ purge=True.".format(pkg)]
                self.state.cache[pkg.name].mark_delete(purge=purge)
            self.logger.verbose("Committing changes...")
            output += ["Committing changes..."]

            logException, logFile = tempfile.TemporaryFile(mode="w+"), tempfile.TemporaryFile()
            self.state._unlock(); pid = os.fork()
            if pid == 0:
                os.setsid(); os.close(sys.stdin.fileno());
                os.dup2(logFile.fileno(), sys.stderr.fileno()); os.dup2(logFile.fileno(), sys.stdout.fileno())
                try:
                    self.state.cache.commit(); exit(0)
                except Exception:
                    json.dump(traceback.format_exc(), logException); exit(1)
            else:
                _, exitStatus = os.waitpid(pid, 0)
                if os.WIFEXITED(exitStatus) and (os.WEXITSTATUS(exitStatus) == 1):
                    logException.seek(0); rc, output = False, json.load(logException)
                else:
                    logFile.seek(0); rc, output = True, [l.decode().replace("\r\n", "").replace("\n", "") for l in logFile.readlines()]
            self.state._lock()
        return rc, output
    # }}}
    # {{{ def checkPolicyDontStartServices(self) -> bool
    @operation
    def checkPolicyDontStartServices(self) -> bool:
        # cf. i) invoke-rc.d(8), ii) /usr/share/doc/init-system-helpers/README.policy-rc.d.gz
        if os.path.exists(self.initScriptPolicyLayerHelperFileName):
            status = subprocess.run(self.initScriptPolicyLayerHelperFileName,
                        subprocess.PIPE, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
            if status.returncode == 101:    # 101 - action forbidden by policy[ii]
                return True, ()
        return False, ()
    # }}}
    # {{{ def cleanArchivesDir(self)
    @operation
    def cleanArchivesDir(self):
        output = []
        for fileName in glob.glob(os.path.join(self.archivesDirName, "*.deb")):
            self.logger.verbose("Deleting cached archive file {}...".format(fileName))
            output += ["Deleting cached archive file {}...".format(fileName)]
            os.remove(fileName)
        return True, output
    # }}}
    # {{{ def downloadArchives(self)
    @operation
    def downloadArchives(self):
        try:
            pkgAcquire, pkgSourceList = apt_pkg.Acquire(), apt_pkg.SourceList()
            self.logger.verbose("Reading main source lists...")
            pkgSourceList.read_main_list()
            self.logger.verbose("Downloading archives...")
            self.state.pkgManager.get_archives(pkgAcquire, pkgSourceList, apt_pkg.PackageRecords(self.state.pkgCache))
            pkgAcquire.run()
        except Exception:
            return False, traceback.format_exc()
        [package.update(install=False) for package in self.state.pkgList.values()]
        return True, ()
    # }}}
    # {{{ def installPackages(self, logException: io.IOBase = tempfile.TemporaryFile, logFile: io.IOBase = tempfile.TemporaryFile, outputLogFile: io.IOBase = tempfile.TemporaryFile)
    @operation
    def installPackages(self, logException: io.IOBase = tempfile.TemporaryFile, logFile: io.IOBase = tempfile.TemporaryFile, outputLogFile: io.IOBase = tempfile.TemporaryFile):
        logException, logFile, outputLogFile = logException(mode="w+"), logFile(), outputLogFile()
        rc, output = False, ()
        self.state._unlock(); pid = os.fork()
        if pid == 0:
            os.setsid(); os.close(sys.stdin.fileno());
            os.dup2(outputLogFile.fileno(), sys.stderr.fileno()); os.dup2(outputLogFile.fileno(), sys.stdout.fileno())
            try:
                self.state.pkgManager.do_install(logFile.fileno()); exit(0)
            except Exception:
                json.dump(traceback.format_exc(), logException); exit(1)
        else:
            _, exitStatus = os.waitpid(pid, 0)
            if os.WIFEXITED(exitStatus) and (os.WEXITSTATUS(exitStatus) == 1):
                logException.seek(0)
                rc, output = False, json.load(logException)
        self.state._lock()
        self.update(); [package.update(install=True) for package in self.state.pkgList.values()]

        logFile.seek(0); outputLogFile.seek(0)
        for line in (line.decode().replace("\n", "") for line in logFile.readlines()):
            matches = re.match(r'^pmerror:([^:]+):([^:]+):(.*)$', line)
            if matches:
                pkgName, _, error = matches[1], matches[2], matches[3]
                self.state.pkgList[pkgName].errors += [error]
        logFile.seek(0)
        return rc, logFile.readlines(), outputLogFile.readlines(), output
    # }}}
    # {{{ def update(self, createCache: bool = False)
    @operation
    def update(self, createCache: bool = False):
        return self.state.update(createCache=createCache)
    # }}}

    def __init__(self, state: AptState, checkPolicyDontStartServices: bool = True, loggerName: str = loggerName):
        self.state, self.logger = state, logging.getLogger(loggerName)
        self.archivesDirName = os.path.join(
            "/",
            apt_pkg.config.get("Dir::Cache"),
            apt_pkg.config.get("Dir::Cache::archives"))
        if checkPolicyDontStartServices and (not self.checkPolicyDontStartServices()):
            raise RuntimeError("Error: starting services post-install enabled")
# }}}
# {{{ class AptPackage(object)(operations: AptOperations, pkg: apt_pkg.Package, state: AptState)
class AptPackage(object):
    # {{{ def _getPackageArchive(self, name: str) -> Tuple[str, Tuple[bool, bool]]: (fileName, (exists, exists_))
    def _getPackageArchive(self, name: str) -> Tuple[str, Tuple[bool, bool]]:
        records = apt_pkg.PackageRecords(self.state.pkgCache)
        records.lookup((self.state.depCache.get_candidate_ver(self.state.pkgCache[name])).file_list[0])
        fileName = os.path.join(self.operations.archivesDirName, os.path.basename(records.filename))
        return (fileName, TransBool(os.path.exists(fileName), False))
    # }}}

    # {{{ def getDepends(self, pkg: apt_pkg.Package = None, depends=(), dependsCache=(), predicate=None) -> Tuple[apt_pkg.Package]
    def getDepends(self, pkg: apt_pkg.Package = None, depends=(), dependsCache=(()), predicate=None) -> Tuple[apt_pkg.Package]:
        depends, currentVer, pkg = (), self.state.pkgCache[self.name].current_ver, (pkg if pkg else self.pkg)
        if currentVer is not None:
            for dependType in currentVer.depends_list.keys():
                for depend in currentVer.depends_list[dependType]:
                    for dependOr in (pkg.target_pkg for pkg in depend if pkg.target_pkg.name not in dependsCache):
                        dependsCache += (dependOr.name,)
                        if predicate is not None and not predicate(dependOr):
                            continue
                        else:
                            depends += (dependOr, *self.getDepends(pkg=dependOr, depends=depends,
                                        dependsCache=dependsCache, predicate=predicate),)
        return tuple(set((p for p in depends)))
    # }}}
    # {{{ def getFilesCommon(self, fn: Union[FunctionType, MethodType] pkg: apt_pkg.Package = None) -> Tuple[apt_pkg.Package]
    def getFilesCommon(self, fn: Union[FunctionType, MethodType], pkg: apt_pkg.Package = None) -> Tuple[apt_pkg.Package]:
        pkg = (pkg if pkg else self.pkg); pkgNameList, services = pkg.name.split("-"), ()
        def predicate(pkg_):
            return len(os.path.commonprefix((pkgNameList, pkg_.name.split("-"),))) and self.state.filterInstalled(pkg_)
        for pkg_ in (*self.getDepends(pkg, predicate=predicate), pkg,):
            services += fn(pkg_)
        return tuple(set(services))
    # }}}
    # {{{ def getInitScripts(self, pkg: apt_pkg.Package = None) -> List[Tuple[str, str]]
    def getInitScripts(self, pkg: apt_pkg.Package = None) -> List[Tuple[str, str]]:
        initScripts, pkg = [], (pkg if pkg else self.pkg)
        for installedFile in (self.state.cache[pkg.name].installed_files if pkg.name in self.state.cache else ()):
            if installedFile.startswith("/etc/init.d/"):
                initScripts += [(installedFile, pkg.name,)]
        return tuple(set(initScripts))
    # }}}
    # {{{ def getReverseDepends(self, pkg: apt_pkg.Package = None, predicate=None) -> Tuple[apt_pkg.Package]
    def getReverseDepends(self, pkg: apt_pkg.Package = None, predicate=None) -> Tuple[apt_pkg.Package]:
        pkg = (pkg if pkg else self.pkg)
        rdepends, rdepends_ = filter(lambda pkg: self.state.filterInstalled(pkg.parent_pkg), self.state.pkgCache[self.name].rev_depends_list), ()
        for rdepend in (pkg_.parent_pkg for pkg_ in rdepends if pkg_.parent_pkg.name not in rdepends_):
            if predicate is not None and not predicate(rdepend):
                continue
            else:
                rdepends_ += (rdepend,)
        return tuple(set(rdepends_))
    # }}}
    # {{{ def getServiceUnitFiles(self, pkg: apt_pkg.Package = None) -> List[Tuple[str, str]]
    def getServiceUnitFiles(self, pkg: apt_pkg.Package = None) -> List[Tuple[str, str]]:
        pkg, serviceUnitFiles = (pkg if pkg else self.pkg), []
        for installedFile in (self.state.cache[pkg.name].installed_files if pkg.name in self.state.cache else ()):
            if  installedFile.startswith("/lib/systemd/system/")\
            and installedFile.endswith(".service"):
                serviceUnitFiles += [(installedFile, pkg.name,)]
        return tuple(set(serviceUnitFiles))
    # }}}
    # {{{ def update(self, transition: bool = None, install: bool = False) -> Tuple[bool, bool]
    def update(self, transition: bool = None, install: bool = False) -> Tuple[bool, bool]:
        if transition is not False:
            self.pkg = self.state.pkgCache[self.pkg.name]
        self.downloaded.set(os.path.exists(self.archive), transition)
        self.halfInstalled.set(self.state.pkgCache[self.pkg.name].current_state in
                self.state.halfInstalledFilter, (True if install else transition))
        self.installed.set(self.state.cache[self.name].is_installed, transition)
        if self.version != self.pkg.current_ver:
            self.version = self.pkg.current_ver; self.upgraded.set(True, transition)
    # }}}

    def __init__(self, operations: AptOperations, pkg: apt_pkg.Package, state: AptState):
        self.operations, self.pkg, self.state = operations, pkg, state
        self.name, self.version = self.pkg.name, self.pkg.current_ver
        self.archive, self.downloaded = self._getPackageArchive(self.name)
        self.errors, self.halfInstalled, self.installed, self.upgraded = [], TransBool(), TransBool(), TransBool()
        self.update(False, False)
# }}}

class AptUpgrades(object):
    """APT package upgrades check application class"""
    # {{{ class AptUpgradesLogger(object)(initialLevel: int = logging.INFO, name: str = loggerName)
    class AptUpgradesLogger(object):
        VERBOSE = 16
        # {{{ class Formatter(logging.Formatter)(fmt: str = "%(asctime)-20s %(message)s", datefmt: str = "%d-%b-%Y %H:%M:%S", style: str = "%")
        class Formatter(logging.Formatter):
            ansiColours = {"CRITICAL":91, "ERROR":91, "WARNING":31, "INFO":93, "VERBOSE":96, "DEBUG":35}

            def format(self, record: logging.LogRecord):
                message = super().format(record)
                if self.ansiEnabled:
                    return "\x1b[{}m{}\x1b[0m".format(self.ansiColours[record.levelname], message)
                else:
                    return message
            def formatTime(self, record: logging.LogRecord, datefmt: str = "%d-%b-%Y %H:%M:%S"):
                return time.strftime(datefmt).upper()
            def __init__(self, fmt: str = "%(asctime)-20s %(message)s", datefmt: str = "%d-%b-%Y %H:%M:%S", style: str = "%"):
                super().__init__(fmt, datefmt, style); self.ansiEnabled = sys.stdout.isatty()
        # }}}

        def verbose(self, message: str, *args, **kwargs):
            if self.logger.isEnabledFor(self.VERBOSE):
                self.logger._log(self.VERBOSE, message, args, **kwargs)

        def __init__(self, initialLevel: int = logging.INFO, name: str = loggerName):
            consoleHandler = logging.StreamHandler(sys.stdout)
            consoleHandler.setFormatter(self.Formatter())
            logging.addLevelName(self.VERBOSE, "VERBOSE")
            logging.basicConfig(handlers=(consoleHandler,))
            self.logger = logging.getLogger(name); self.logger.verbose = self.verbose
            self.logger.setLevel(initialLevel)
    # }}}
    # {{{ class AptUpgradesReporter(object)(operations: AptOperations, state: AptState, ignoreLibs: bool = True, loggerName: str = loggerName, newFlag: bool = False)
    class AptUpgradesReporter(object):
        """APT upgrades report generation class"""
        # {{{ Class variables
        cacheNewCountMax = 2
        cacheNewFileName = "~/.cache/AptUpgrades.json"
        reportTemplate = '''\
APT package upgrade report
==========================

@if(pkglist)
The following packages have changed state:
{pkgList}
(where '>': downloaded, '!': error, '%': half-installed, '=': installed, '^': upgraded)
@endif
@if(reverseDepends)

The following reverse dependencies, sans library packages, may be affected:
{reverseDepends}
@endif
@if(initScriptsCommon)

This upgrade encompasses the following init(1) rc scripts:
{initScriptsCommon}
@endif
@if(initScripts)

The reverse dependencies, sans library packages, listed above encompass the following init(1) rc scripts:
{initScripts}
@endif
@if(serviceUnitsCommon)

This upgrade encompasses the following systemd service units:
{serviceUnitsCommon}
@endif
@if(serviceUnits)

The reverse dependencies, sans library packages, listed above encompass the following systemd service units:
{serviceUnits}
@endif
@if(downloadArchives)

An exception was raised during download:
{downloadArchives}
@endif
@if(installPackages)

An exception was raised during installation:
{installPackages}
@endif
@if(installPackages_)

The following output was generated by APT/dpkg during installation:
{installPackages_}
@endif
@if(autoRemove)

The following output was generated during package auto-remove:
{autoRemove}
@endif
@if(cleanArchivesDir)

The following output was generated during cleaning of the archives directory:
{cleanArchivesDir}
@endif'''
        # }}}
        # {{{ def _isReportNew(self, report: str) -> bool: printFlag
        def _isReportNew(self, report: str) -> bool:
            if self.newFlag:
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
        # {{{ def print(self, file: io.IObase = sys.stdout)
        def print(self, file: io.IOBase = sys.stdout):
            isEmpty, report = True, '''\
APT package upgrade report
=========================='''

            # {{{ names
            names = []
            for name, package in self.state.pkgList.items():
                namePrefix = ""
                if package.downloaded and package.downloaded.transition:
                    namePrefix += ">"
                if len(package.errors):
                    namePrefix += "!"
                if package.halfInstalled and package.halfInstalled.transition:
                    namePrefix += "%"
                if package.installed and package.installed.transition:
                    namePrefix += "="
                if package.upgraded and package.upgraded.transition:
                    namePrefix += "^"
                names += [namePrefix + name]
            isEmpty = len(names) == 0
            if not isEmpty:
                report += '''

The following packages have changed state:
{}
(where '>': downloaded, '!': error, '%': half-installed, '=': installed, '^': upgraded)\
'''.format(", ".join(sorted(tuple(set(names)))))
            # }}}
            # {{{ reverseDepends
            reverseDepends_ = ", ".join(self.reverseDepends)
            if (names != reverseDepends_) and len(reverseDepends_):
                report += '''

The following reverse dependencies, sans library packages, may be affected:
{}'''.format(", ".join(self.reverseDepends))
            # }}}
            # {{{ initScripts
            initScripts_ = "\n".join(sorted(["{0:48s}[owned by {1}]".format(*u) for u in self.initScripts]))
            initScriptsCommon_ = "\n".join(sorted(["{0:48s}[owned by {1}]".format(*u) for u in self.initScriptsCommon]))
            if len(initScripts_) and len(initScriptsCommon_) and (initScripts_ == initScriptsCommon_):
                report += '''

This upgrade and its reverse dependencies, sans library packages, encompass the following init(1) rc scripts:
{}'''.format(initScripts_)
            else:
                if len(initScripts_):
                    report += '''

This upgrade encompasses the following init(1) rc scripts:
{}'''.format(initScripts_)
                if len(self.initScriptsCommon):
                    report += '''

The reverse dependencies, sans library packages, listed above encompass the following init(1) rc scripts:
{}'''.format(initScriptsCommon_)
            # }}}
            # {{{ serviceUnits
            serviceUnits_ = "\n".join(sorted(["{0:48s}[owned by {1}]".format(*u) for u in self.serviceUnits]))
            serviceUnitsCommon_ = "\n".join(sorted(["{0:48s}[owned by {1}]".format(*u) for u in self.serviceUnitsCommon]))
            if len(serviceUnits_) and len(serviceUnitsCommon_) and (serviceUnits_ == serviceUnitsCommon_):
                report += '''

This upgrade and its reverse dependencies, sans library packages, encompass the following systemd service units:
{}'''.format(serviceUnits_)
            else:
                if len(serviceUnits_):
                    report += '''

This upgrade encompasses the following systemd service units:
{}'''.format(serviceUnits_)
                if len(self.serviceUnitsCommon):
                    report += '''

The reverse dependencies, sans library packages, listed above encompass the following systemd service units:
{}'''.format(serviceUnitsCommon_)
            # }}}

            # {{{ operations.{downloadArchives,installPackages}
            if self.operations.downloadArchives.state is not None\
            and not self.operations.downloadArchives.state[0]:
                isEmpty = False; report += '''

An exception was raised during download:
{}'''.format("\n".join(self.operations.downloadArchives.state[1]))
            # }}}
            # {{{ operations.installPackages
            if self.operations.installPackages.state is not None\
            and not self.operations.installPackages.state[0]:
                isEmpty = False; report += '''

An exception was raised during installation:
{}'''.format(self.operations.installPackages.state[3])
                lines = [line.decode().replace("\n", "") for line in self.operations.installPackages.state[2]]
                lines = tuple(filter(lambda line:
                    (line.startswith("(Reading database ... ")
                    and line.endswith("currently installed.)"))
                    or not line.startswith("(Reading database ... "), lines))
                if len(lines):
                    isEmpty = False; report += '''

The following output was generated by APT/dpkg:
{}'''.format("\n".join(lines))
            # }}}
            # {{{ operations.autoRemove
            if self.operations.autoRemove.state is not None\
            and len(self.operations.autoRemove.state[1]):
                isEmpty = False; report += '''

The following output was generated during package auto-remove:
{}'''.format("\n".join(self.operations.autoRemove.state[1]))
            # }}}
            # {{{ operations.cleanArchivesDir
            if self.operations.cleanArchivesDir.state is not None\
            and len(self.operations.cleanArchivesDir.state[1]):
                isEmpty = False; report += '''

The following output was generated during cleaning of the archives directory:
{}'''.format("\n".join(self.operations.cleanArchivesDir.state[1]))
            # }}}

            if not isEmpty and self._isReportNew(report):
                print(report, file=file)
            elif isEmpty:
                self.logger.verbose("(Skipping printing empty report)")
            else:
                self.logger.verbose("(Skipping printing non-empty and non-new report)")
        # }}}}

        # {{{ def generateReport(self)
        def generateReport(self):
            report = ""
            varDict = {
                "pkgList": (", ".join(sorted(tuple(set((name for name in self.state.pkgList.keys())))))),
                "reverseDepends": (", ".join(self.reverseDepends)),
                "initScriptsCommon": ("\n".join(sorted(["{0:48s}[owned by {1}]".format(*u) for u in self.initScriptsCommon]))),
                "initScripts": ("\n".join(sorted(["{0:48s}[owned by {1}]".format(*u) for u in self.initScripts]))),
                "serviceUnitsCommon": ("\n".join(sorted(["{0:48s}[owned by {1}]".format(*u) for u in self.serviceUnitsCommon]))),
                "serviceUnits": ("\n".join(sorted(["{0:48s}[owned by {1}]".format(*u) for u in self.serviceUnits]))),
                "downloadArchives": ("\n".join(self.operations.downloadArchives.state[1] if self.operations.downloadArchives.state is not None else ())),
                "installPackages": ("\n".join([line.decode().replace("\n", "") for line in (self.operations.installPackages.state[1] if self.operations.installPackages.state is not None else ())])),
                "installPackages_": ("\n".join([line.decode().replace("\n", "") for line in (self.operations.installPackages.state[2] if self.operations.installPackages.state is not None else ())])),
                "autoRemove": ("\n".join(self.operations.autoRemove.state[1] if self.operations.autoRemove.state is not None else ())),
                "cleanArchivesDir": ("\n".join(self.operations.cleanArchivesDir.state[1] if self.operations.cleanArchivesDir.state is not None else ())),
            }
            try:
                lineNum, template = 0, self.reportTemplate.split("\n")
                while True:
                    def reportLine(lineNum, report):
                        line, lineNum = template[lineNum], lineNum + 1
                        if line.startswith("@if("):
                            matches = re.match(r'^@if\((.+)\)$', line)
                            if  (matches is not None)\
                            and (matches[1] in locals())\
                            and (len(locals()[matches[1]])):
                                matches_ = True
                            else:
                                matches_ = False
                            while True:
                                line, lineNum = template[lineNum], lineNum + 1
                                if line == "@endif":
                                    break
                                elif matches_:
                                    lineNum, report = reportLine(lineNum, report)
                        else:
                            report += line.format(**varDict) + "\n"
                        return lineNum, report
                    if lineNum >= len(template):
                        break
                    else:
                        lineNum, report = reportLine(lineNum, report)
            except Exception:
                raise
            return report
        # }}}

        def __init__(self, operations: AptOperations, state: AptState, ignoreLibs: bool = True, loggerName: str = loggerName, newFlag: bool = False):
            self.operations, self.state, self.ignoreLibs, self.newFlag = operations, state, ignoreLibs, newFlag
            self.logger = logging.getLogger(loggerName)

            self.cacheNewFileName = os.path.abspath(os.path.expanduser(self.cacheNewFileName))
            if not os.path.exists(os.path.dirname(self.cacheNewFileName)):
                os.makedirs(os.path.dirname(self.cacheNewFileName))

            self.initScripts, self.initScriptsCommon, self.reverseDepends, self.serviceUnits, self.serviceUnitsCommon = [], [], [], [], []
            for pkg in self.state.pkgList.values():
                self.initScripts += pkg.getInitScripts()
                self.initScriptsCommon += pkg.getFilesCommon(pkg.getInitScripts)
                reverseDepends = pkg.getReverseDepends(predicate=lambda pkg_:
                    (ignoreLibs and not pkg_.name.startswith("lib")) or (not ignoreLibs))
                self.reverseDepends += [pkg_.name for pkg_ in reverseDepends]
                self.serviceUnits += pkg.getServiceUnitFiles()
                self.serviceUnitsCommon += pkg.getFilesCommon(pkg.getServiceUnitFiles)
            self.initScripts = sorted(tuple(set(self.initScripts)))
            self.initScriptsCommon = sorted(tuple(set(self.initScriptsCommon)))
            self.reverseDepends = sorted(tuple(set(self.reverseDepends)))
            self.serviceUnits = sorted(tuple(set(self.serviceUnits)))
            self.serviceUnitsCommon = sorted(tuple(set(self.serviceUnitsCommon)))
            print(self.generateReport())
    # }}}

    # {{{ Class variables
    optionList = {
        "-A":{"_alias":("--autoremove",), "action":"store_true", "default":False, "dest":"autoremove", "help":"post-autoremove w/ purge"},
        "-C":{"_alias":("--clean-archives",), "action":"store_true", "default":False, "dest":"clean_archives", "help":"post-clean archives directory"},
        "-d":{"_alias":("--download",), "action":"store_true", "default":False, "dest":"download", "help":"download upgradeable packages"},
        "-i":{"_alias":("--install",), "action":"store_true", "default":False, "dest":"install", "help":"install upgradeable packages (implies -d)", "_implies":("download",)},
        "-N":{"_alias":("--new",), "action":"store_true", "default":False, "dest":"new", "help":("inhibit report printing if unchanged since last " + str(AptUpgradesReporter.cacheNewCountMax))},
        "-t":{"_alias":("--test",), "action":"store", "default":False, "dest":"packages", "metavar":"package[,..]", "help":"test with fixed set of upgradeable packages"},
        "-v":{"_alias":("--verbose",), "action":"store_true", "default":False, "dest":"verbose", "help":"increase verbosity"},
    }
    # }}}
    # {{{ def _initArgsLogger(self) -> Tuple[argparse.Namespace, AptUpgradesLogger]: args, logger
    def _initArgsLogger(self) -> Tuple[argparse.Namespace, AptUpgradesLogger]:
        parser = argparse.ArgumentParser(description="")
        for name, option in self.optionList.items():
            parser.add_argument(name,
                *(option["_alias"] if "_alias" in option else ()),
                **{k:v for k, v in option.items() if not k.startswith("_")})
        args = parser.parse_args()
        for option in self.optionList.values():
            for nameImplied in (option["_implies"] if "_implies" in option else ()):
                setattr(args, nameImplied, True)
        logger = self.AptUpgradesLogger(initialLevel=self.AptUpgradesLogger.VERBOSE if args.verbose else logging.INFO)
        return args, logging.getLogger(loggerName)
    # }}}

    # {{{ def main(self) -> int
    def main(self) -> int:
        return 0 if self.synchronise() else 1
    # }}}
    # {{{ def synchronise(self) -> bool
    def synchronise(self) -> bool:
        try:
            with AptState() as aptState:
                aptOperations = AptOperations(aptState)
                if self.args.download or self.args.install:
                    if self.args.packages:
                        pkgList = [aptState.pkgCache[name] for name in self.args.packages.split(",")]
                    else:
                        pkgList = tuple(filter(lambda pkg:
                                (           aptState.filterHalfInstalled(pkg)
                                 or         aptState.filterUpgradable(pkg)
                                 and not    aptState.filterPhasing(pkg)),
                                aptState.pkgCache.packages))
                    if len(pkgList):
                        aptState.markPackages(aptOperations, pkgList)
                        if  aptOperations.downloadArchives()\
                        and self.args.install:
                            aptOperations.installPackages()
                if self.args.autoremove:
                    aptOperations.autoRemove(purge=True)
                if self.args.clean_archives:
                    aptOperations.cleanArchivesDir()
                self.AptUpgradesReporter(aptOperations, aptState, newFlag=self.args.new).print()
        except Exception:
            for line in traceback.format_exc().split("\n"):
                self.logger.error(line)
            return False
        return True
    # }}}

    def __init__(self):
        self.args, self.logger = self._initArgsLogger()

if __name__ == "__main__":
    exit(AptUpgrades().main())
