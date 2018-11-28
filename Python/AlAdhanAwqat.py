#!/usr/bin/env python3
#
# AlAdhanAwqat.py -- Obtain daily awqāt from AlAdhan.com
# Copyright (c) 2018 Lucio Andrés Illanes Albornoz <lucio@lucioillanes.de>
# This project is licensed under the terms of the MIT licence.
#

from getopt import getopt, GetoptError
import hashlib, json, os, requests, sys, time, urllib.request

class AlAdhanAwqat(object):
    """Fetch monthly awqāt from AlAdhan.com"""
    apiUrlBase = "http://api.aladhan.com/v1/calendarByCity"
    optionsDefault = {
        "awqatFilter":["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"],
        "cachePathBase":os.path.expanduser(os.path.join("~", ".cache", "AlAdhanAwqat")),
        "city":None, "country":None, "forceFetch":False, "help":False, "outputFormat":"list",
        "verbose":False, "waqtOffset":15}
    optionsString = "c:C:fF:hp:t:vw:"
    optionsStringMap = {
        "c":"city", "C":"cachePathBase", "f":"forceFetch", "F":"awqatFilter",
        "h":"help", "p":"outputFormat", "t":"country", "v":"verbose", "w":"waqtOffset"}

    # {{{ _log(self, msg): Log single message to std{err,out} w/ timestamp
    def _log(self, msg, isError=False, isVerbose=False):
        if isError:
            print("{} [91mError: {}[0m".format(time.strftime("%d-%^b-%Y %H:%M:%S"), msg), file=sys.stderr)
        elif isVerbose and self.options["verbose"]:
            print("{} [36m{}[0m".format(time.strftime("%d-%^b-%Y %H:%M:%S"), msg))
        elif not isVerbose:
            print("{} {}".format(time.strftime("%d-%^b-%Y %H:%M:%S"), msg))
    # }}}
    # {{{ _usage(self, argv0, options): XXX
    def _usage(self, argv0, options):
        if options["city"] == None:
            print("error: missing city", file=sys.stderr)
        if options["country"] == None:
            print("error: missing country", file=sys.stderr)
        print("usage: {} [-h]".format(argv0), file=sys.stderr)
        print("       [-c city] [-C dname] [-f] [-F timing[,timing..]]".format(argv0), file=sys.stderr)
        print("       [-p list|tmux] [-t country] [-v] [-w offset]".format(argv0), file=sys.stderr)
        print("", file=sys.stderr)
        print("       -h....................: show this screen", file=sys.stderr)
        print("       -c city...............: specifies location city", file=sys.stderr)
        print("       -C dname..............: specifies cache directory pathname", file=sys.stderr)
        print("       -f....................: force (re)fetch from AlAdhan.com (defaults to: {})".format(self.optionsDefault["forceFetch"]), file=sys.stderr)
        print("       -F timing[,timing..]..: override default timings filter (defaults to: {})".format(", ".join(self.optionsDefault["awqatFilter"])), file=sys.stderr)
        print("       -p list|tmux..........: specifies output format (defaults to {})".format(self.optionsDefault["outputFormat"]), file=sys.stderr)
        print("       -t country............: specifies location country ", file=sys.stderr)
        print("       -v....................: increase verbosity (defaults to: {})".format(self.optionsDefault["verbose"]), file=sys.stderr)
        print("       -w offset.............: specifies waqt [-+] offset for -p tmux (defaults to: {})".format(self.optionsDefault["waqtOffset"]), file=sys.stderr)
    # }}}
    # {{{ _getData(self, apiUrlBase, cachePathBase, city, country, forceFetch): XXX
    def _getData(self, apiUrlBase, cachePathBase, city, country, forceFetch):
        cacheKey = "{}\0{}\0{}\0{}\0".format(apiUrlBase, city, country, time.strftime("%d%m%Y"))
        cacheFileName = hashlib.sha256(cacheKey.encode()).hexdigest()
        if not os.path.isdir(cachePathBase):
            os.makedirs(cachePathBase)
        cacheFilePathName = os.path.join(cachePathBase, cacheFileName)
        if not os.path.exists(cacheFilePathName) or forceFetch:
            apiUrl = "{}?city={}&country={}".format(apiUrlBase, city, country)
            self._log("Fetching [4m{apiUrl}[0m...".format(**locals()), isVerbose=True)
            data = requests.get(apiUrl).json()
            if data["status"] == "OK":
                with open(cacheFilePathName, "w+") as fileObject:
                    json.dump(data["data"], fileObject)
                return True, data["status"], data["data"]
            else:
                return False, "OK", data["data"]
        else:
            with open(cacheFilePathName, "r") as fileObject:
                data = json.load(fileObject)
            return True, "OK", data
    # }}}
    # {{{ _printAsList(self, timings): XXX
    def _printAsList(self, timings):
        timingsPadding = 0
        for timingKey, timingValue in timings.items():
            timingsPadding = max(timingsPadding, len(timingKey))
        for timingKey, timingValue in sorted(timings.items(), key=lambda kv: kv[1]):
            print(("{:" + str(timingsPadding) + "}: {}").format(timingKey, timingValue))
    # }}}
    # {{{ _printAsTmux(self, timings): XXX
    def _printAsTmux(self, timings):
        foundNext, timeNow, timingsList = False, time.localtime(), []
        timeNowMins = (timeNow.tm_hour * 60) + timeNow.tm_min
        for _, timingValue in sorted(timings.items(), key=lambda kv: kv[1]):
            timeTiming = time.strptime(timingValue, "%H:%M")
            timeTimingMins = (timeTiming.tm_hour * 60) + timeTiming.tm_min
            if   timeNowMins == timeTimingMins                                          \
            or   ((timeNowMins >= (timeTimingMins - int(self.options["waqtOffset"])))   \
            and   (timeNowMins <= (timeTimingMins + int(self.options["waqtOffset"])))):
                timingsList += ["#[fg=brightwhite]" + timingValue + "#[fg=default]"]
            elif (timeNowMins < timeTimingMins) and not foundNext:
                timingsList += ["#[fg=brightyellow]" + timingValue + "#[fg=default]"]
                foundNext = True
            else:
                timingsList += [timingValue]
        print(" ".join(timingsList))
    # }}}
    # {{{ synchronise(self): XXX
    def synchronise(self):
        rc, status, data = self._getData(
            self.apiUrlBase,
            self.options["cachePathBase"],
            self.options["city"],
            self.options["country"],
            self.options["forceFetch"])
        if rc:
            dayIdx, timingsDict = (int(time.strftime("%d")) - 1), {}
            for timingKey, timingValue in data[dayIdx]["timings"].items():
                if timingKey in self.options["awqatFilter"]:
                    timingValue_ = timingValue.split(" ")[0]
                    timingsDict[timingKey] = timingValue_
            if self.options["outputFormat"] == "list":
                self._printAsList(timingsDict)
            elif self.options["outputFormat"] == "tmux":
                self._printAsTmux(timingsDict)
            else:
                self._log("unknown output format `{}'".format(self.options["outputFormat"]), isError=True)
                rc = 1
        else:
            self._log("non-successful status `{}' received, message: `{}'".format(status, data), isError=True)
        return rc == 0
    # }}}

    #
    # __init__(self, argv): initialisation method
    def __init__(self, argv):
        options = self.optionsDefault.copy()
        optionsList, args = getopt(argv[1:], self.optionsString)
        for optionChar, optionArg in optionsList:
            optionName = self.optionsStringMap[optionChar[1:]]
            if type(self.optionsDefault[optionName]) == bool:
                options[optionName] = True
            else:
                options[optionName] = optionArg
        if options["help"]              \
        or options["city"] == None      \
        or options["country"] == None:
            self._usage(argv[0], options); exit(0);
        else:
            self.options = options

if __name__ == "__main__":
    exit(AlAdhanAwqat(sys.argv).synchronise())

# vim:expandtab foldmethod=marker sw=4 ts=4 tw=120
