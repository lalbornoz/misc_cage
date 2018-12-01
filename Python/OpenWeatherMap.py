#!/usr/bin/env python3
#
# OpenWeatherMap.py -- Obtain daily weather from OpenWeatherMap.org
# Copyright (c) 2018 Lucio Andrés Illanes Albornoz <lucio@lucioillanes.de>
# This project is licensed under the terms of the MIT licence.
#

from getopt import getopt, GetoptError
from OpenWeatherMapApiKey import OpenWeatherMapApiKey
import hashlib, json, os, requests, sys, time, urllib.request

class OpenWeatherMap(object):
    """Obtain daily weather from OpenWeatherMap.org"""
    # {{{ Class attributes
    apiUrlBase = "https://api.openweathermap.org/data/2.5/weather"
    attrSuffixes = {
        "main.humidity":"%",
        "main.pressure":" hPa",
        "main.temp":"°",
        "main.temp_min":"°",
        "main.temp_max":"°",
        "name":"",
        "visibility":"",
        "wind.deg":"°",
        "wind.speed":""}
    attrTitles = {
        "main.humidity":"Humidity",
        "main.pressure":"Pressure",
        "main.temp":"Temperature",
        "main.temp_min":"Temperature (min.)",
        "main.temp_max":"Temperature (max.)",
        "name":"Location",
        "visibility":"Visibility",
        "wind.deg":"Wind (degree)",
        "wind.speed":"Wind (speed)"}
    helpString = """usage: {argv0} [-h]
       [-a seconds] [-c city] [-C dname] [-f] [-F attr[,attr..]]
       [-p list|tmux] [-t country] [-u imperial|metric] [-v]

       -h..................: show this screen
       -a seconds..........: purge cached data after specified amount of seconds (defaults to: {self.optionsDefault[purgeAfter]})
       -c city.............: specifies location city
       -C dname............: specifies cache directory pathname
       -f..................: force (re)fetch from OpenWeatherMap.org (defaults to: {self.optionsDefault[forceFetch]})
       -F attr[,attr..]....: override default attribute filter (defaults to: {self.optionsDefault[attrFilter]})
       -p list|tmux........: specifies output format (defaults to {self.optionsDefault[outputFormat]})
       -t country..........: specifies location country
       -t imperial|metric..: specifies imperial or metric units (defaults to {self.optionsDefault[units]})
       -v..................: increase verbosity (defaults to: {self.optionsDefault[verbose]})"""
    optionsDefault = {
        "attrFilter":["main.humidity", "main.pressure", "main.temp", "main.temp_min",
            "main.temp_max", "name", "visibility", "wind.deg", "wind.speed"],
        "cachePathBase":os.path.expanduser(os.path.join("~", ".cache", "OpenWeatherMap")),
        "city":None, "country":None, "forceFetch":False, "help":False, "outputFormat":"list",
        "purgeAfter":3600, "units":"metric", "verbose":False}
    optionsString = "a:c:C:fF:hp:t:u:v"
    optionsStringMap = {
        "a":"purgeAfter", "c":"city", "C":"cachePathBase", "f":"forceFetch", "F":"attrFilter",
        "h":"help", "p":"outputFormat", "t":"country", "u":"units", "v":"verbose"}
    # }}}
    # {{{ _flattenDict(self, oldDict, parentKey, sepChar): XXX
    def _flattenDict(self, oldDict, parentKey, sepChar):
        flatDict = {}
        for oldKey, oldVal in oldDict.items():
            if type(oldVal) == dict:
                flatDict = {**flatDict, **self._flattenDict(oldVal, oldKey, sepChar)}
            else:
                flatDict[oldKey if parentKey == "" else parentKey + sepChar + oldKey] = oldVal
        return flatDict
    # }}}
    # {{{ _getData(self, apiUrlBase, cachePathBase, city, country, forceFetch, units): XXX
    def _getData(self, apiUrlBase, cachePathBase, city, country, forceFetch, units):
        cacheKey = "{}\0{}\0{}\0{}\0{}\0".format(apiUrlBase, city, country, time.strftime("%d%m%Y"), units)
        cacheFileName = hashlib.sha256(cacheKey.encode()).hexdigest()
        cacheFilePathName = os.path.join(cachePathBase, cacheFileName)
        rc = False
        if not forceFetch:
            rc, status, data = self._getDataCache(apiUrlBase, cacheFilePathName)
        if not rc:
            rc, status, data = self._getDataFetch(apiUrlBase, cacheFilePathName, city, country, units)
        if rc:
            self._purgeCache(cacheFilePathName, cachePathBase)
        return rc, status, data
    # }}}
    # {{{ _getDataCache(self, apiUrlBase, cacheFilePathName): XXX
    def _getDataCache(self, apiUrlBase, cacheFilePathName):
        if not os.path.isdir(os.path.dirname(cacheFilePathName)):
            os.makedirs(os.path.dirname(cacheFilePathName))
        if not os.path.exists(cacheFilePathName):
            return False, None, None
        else:
            with open(cacheFilePathName, "r") as fileObject:
                data = json.load(fileObject)
            return True, 200, data
    # }}}
    # {{{ _getDataFetch(self, apiUrlBase, cacheFilePathName, city, country, units): XXX
    def _getDataFetch(self, apiUrlBase, cacheFilePathName, city, country, units):
        apiUrl = "{}?APPID={}&units={}&q={},+{}".format(
            apiUrlBase, OpenWeatherMapApiKey.openWeatherMapApiKey, units, city, country)
        self._log("Fetching [4m{apiUrl}[0m...".format(**locals()), isVerbose=True)
        data, rc = requests.get(apiUrl).json(), False
        if data["cod"] == 200:
            with open(cacheFilePathName, "w+") as fileObject:
                json.dump(data, fileObject)
            rc = True
        return rc, data["cod"], data
    # }}}
    # {{{ _log(self, msg): Log single message to std{err,out} w/ timestamp
    def _log(self, msg, isError=False, isVerbose=False):
        if isError:
            print("{} [91mError: {}[0m".format(time.strftime("%d-%^b-%Y %H:%M:%S"), msg), file=sys.stderr)
        elif isVerbose and self.options["verbose"]:
            print("{} [36m{}[0m".format(time.strftime("%d-%^b-%Y %H:%M:%S"), msg))
        elif not isVerbose:
            print("{} {}".format(time.strftime("%d-%^b-%Y %H:%M:%S"), msg))
    # }}}
    # {{{ _printAsList(self, attrsPretty): XXX
    def _printAsList(self, attrsPretty):
        attrsPadding = 0
        for attrKey, attrValue in attrsPretty.items():
            attrsPadding = max(attrsPadding, len(attrKey))
        for attrKey, attrValue in sorted(attrsPretty.items(), key=lambda kv: kv[0]):
            print(("{:" + str(attrsPadding) + "}: {}").format(attrKey, attrValue))
    # }}}
    # {{{ _printAsTmux(self, attrsPretty): XXX
    def _printAsTmux(self, attrsPretty):
        attrsList = []
        for _, attrValue in sorted(attrsPretty.items(), key=lambda kv: kv[0]):
            attrsList += [str(attrValue)]
        print(" ".join(attrsList))
    # }}}
    # {{{ _purgeCache(self, cacheFilePathName, cachePathBase): XXX
    def _purgeCache(self, cacheFilePathName, cachePathBase):
        if os.path.isdir(cachePathBase):
            for cacheFileName in os.listdir(cachePathBase):
                if  os.path.isfile(os.path.join(cachePathBase, cacheFileName))  \
                and cacheFileName != os.path.basename(cacheFilePathName):
                    cacheFileMTime = int(os.path.getmtime(os.path.join(cachePathBase, cacheFileName)))
                    timeNow = int(time.time())
                    if  timeNow > cacheFileMTime                                \
                    and ((timeNow - cacheFileMTime) >= int(self.options["purgeAfter"])):
                        os.remove(os.path.join(cachePathBase, cacheFileName))
    # }}}
    # {{{ _usage(self, argv0, options): XXX
    def _usage(self, argv0, options):
        if options["city"] == None:
            print("error: missing city", file=sys.stderr)
        if options["country"] == None:
            print("error: missing country", file=sys.stderr)
        print(self.helpString.format(**locals()))
    # }}}
    # {{{ synchronise(self): XXX
    def synchronise(self):
        rc, status, data = self._getData(
            self.apiUrlBase,
            self.options["cachePathBase"],
            self.options["city"],
            self.options["country"],
            self.options["forceFetch"],
            self.options["units"])
        if rc:
            attrsDict, attrsFlatDict, attrsPretty = {}, self._flattenDict(data, "", "."), {}
            for attrKey, attrValue in attrsFlatDict.items():
                if attrKey in self.options["attrFilter"]:
                    attrsDict[attrKey] = attrValue
            for attrKey, attrValue in attrsDict.items():
                attrsPretty[self.attrTitles[attrKey]] = str(attrValue) + self.attrSuffixes[attrKey]
            if self.options["outputFormat"] == "list":
                self._printAsList(attrsPretty)
            elif self.options["outputFormat"] == "tmux":
                self._printAsTmux(attrsPretty)
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
            if type(options["attrFilter"]) == str:
                options["attrFilter"] = options["attrFilter"].split(",")
            self.options = options

if __name__ == "__main__":
    exit(OpenWeatherMap(sys.argv).synchronise())

# vim:expandtab foldmethod=marker sw=4 ts=4 tw=120
