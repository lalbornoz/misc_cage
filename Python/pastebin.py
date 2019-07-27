#! /usr/bin/env python
import urllib2, urllib, optparse, sys, os.path

# user editable config
#
# user key
# use -k option to get this
userkey = ""
#
# automatic syntax highlighting choice by file extension
# defaults are pastebin's common extensions from web interface
# add your own based on the filetypes you use
syntax = {".sh":"bash", ".c":"c", ".h":"c", ".cpp":"cpp", ".cs":"csharp", ".css":"css", ".html":"html", ".htm":"html", ".java":"java", ".js":"javascript", ".lua":"lua", ".pl":"perl", ".php":"php", ".py":"python", ".rb":"rails", ".patch":"diff"}
#
# end of config

parser = optparse.OptionParser(usage="usage: %prog [OPTIONS] [FILE]...\nPastebin FILE(s) or standard input")
parser.add_option("-n", "--name", dest="name", metavar="NAME", help="Name/title of paste (ignored for multiple files)")
parser.add_option("-s", "--syntax", dest="syntax", metavar="FORMAT", help="Specify syntax format (common types will be guessed from filename otherwise, use -s none to stop this)")
parser.add_option("-p", "--private", dest="private", action="store_true", default=False, help="Private paste")
parser.add_option("-e", "--expire", dest="expire", metavar="EXPIRY", help="Specify expiry date: N = never, 10M = 10 minutes, 1H = 1 hour, 1D = 1 day, 1M = 1 month")
parser.add_option("-i", "--interactive", dest="interactive", default=False, action="store_true", help="Interactive mode - echoes everything received on stdin to stdout so programs which require console input can be used piped into Pastebin")
parser.add_option("-q", "--quiet", dest="quiet", action="store_true", default=False, help="Suppress information messages and print only URLs")
parser.add_option("-l", "--login", dest="login", action="store_true", default=False, help="Login to Pastebin")
parser.add_option("-k", "--key", dest="getkey", action="store_true", default=False, help="Return user key to avoid giving username and password in future")

(options, args) = parser.parse_args()
devkey = "6c71766cdadff9f33347e80131397ac2" # don't edit this

def get_user_key():
    username = raw_input("Enter username: ")
    from getpass import getpass
    password = getpass()

    request = {"api_dev_key":devkey, "api_user_name":username, "api_user_password":password}

    try:
        reply = urllib2.urlopen("http://pastebin.com/api/api_login.php", urllib.urlencode(request))
    except urllib2.URLError:
        if not options.quiet:
            print "Error uploading", filename + ":", "Network error"
        exit(2)
    else:
        reply = reply.read()
        if "Bad API request" in reply:
            if not options.quiet:
                print "Pastebin login error:", reply
            exit(2)
        else:
            return reply

def guess_syntax(ext):
    return syntax.get(ext, "text")    

if options.getkey:
    userkey = get_user_key()
    print "Your user key is:", userkey
    print "You may edit the userkey value at the top of this script to skip username/password requests in future."
    if not args:
        exit()

# validate expiry/format options
if options.syntax:
    syntaxes = ('4cs', '6502acme', '6502kickass', '6502tasm', 'abap', 'actionscript',
    'actionscript3', 'ada', 'algol68', 'apache', 'applescript', 'apt_sources', 'asm', 'asp',
    'autoconf', 'autohotkey', 'autoit', 'avisynth', 'awk', 'bascomavr', 'bash', 'basic4gl',
    'bibtex', 'blitzbasic', 'bnf', 'boo', 'bf', 'c', 'c_mac', 'cil', 'csharp', 'cpp', 'cpp-qt',
    'c_loadrunner', 'caddcl', 'cadlisp', 'cfdg', 'chaiscript', 'clojure', 'klonec', 'klonecpp',
    'cmake', 'cobol', 'coffeescript', 'cfm', 'css', 'cuesheet', 'd', 'dcs', 'delphi', 'oxygene',
    'diff', 'div', 'dos', 'dot', 'e', 'ecmascript', 'eiffel', 'email', 'epc', 'erlang', 'fsharp',
    'falcon', 'fo', 'f1', 'fortran', 'freebasic', 'gambas', 'gml', 'gdb', 'genero', 'genie',
    'gettext', 'go', 'groovy', 'gwbasic', 'haskell', 'hicest', 'hq9plus', 'html4strict', 'html5',
    'icon', 'idl', 'ini', 'inno', 'intercal', 'io', 'j', 'java', 'java5', 'javascript', 'jquery',
    'kixtart', 'latex', 'lb', 'lsl2', 'lisp', 'llvm', 'locobasic', 'logtalk', 'lolcode',
    'lotusformulas', 'lotusscript', 'lscript', 'lua', 'm68k', 'magiksf', 'make', 'mapbasic',
    'matlab', 'mirc', 'mmix', 'modula2', 'modula3', '68000devpac', 'mpasm', 'mxml', 'mysql',
    'newlisp', 'text', 'nsis', 'oberon2', 'objeck', 'objc', 'ocaml-brief', 'ocaml', 'pf', 'glsl',
    'oobas', 'oracle11', 'oracle8', 'oz', 'pascal', 'pawn', 'pcre', 'per', 'perl', 'perl6',
    'php', 'php-brief', 'pic16', 'pike', 'pixelbender', 'plsql', 'postgresql', 'povray',
    'powershell', 'powerbuilder', 'proftpd', 'progress', 'prolog', 'properties', 'providex',
    'purebasic', 'pycon', 'python', 'q', 'qbasic', 'rsplus', 'rails', 'rebol', 'reg', 'robots',
    'rpmspec', 'ruby', 'gnuplot', 'sas', 'scala', 'scheme', 'scilab', 'sdlbasic', 'smalltalk',
    'smarty', 'sql', 'systemverilog', 'tsql', 'tcl', 'teraterm', 'thinbasic', 'typoscript',
    'unicon', 'uscript', 'vala', 'vbnet', 'verilog', 'vhdl', 'vim', 'visualprolog', 'vb',
    'visualfoxpro', 'whitespace', 'whois', 'winbatch', 'xbasic', 'xml', 'xorg_conf', 'xpp',
    'yaml', 'z80', 'zxbasic')
    if options.syntax.lower() not in syntaxes:
        if not options.quiet:
            print "Error: unknown syntax. Valid values are (detailed explanation: http://pastebin.com/api#5 ):"
            print syntaxes
        exit(1)

if options.expire:
    expires = ("N", "10M", "1H", "1D", "1M")
    if options.expire.upper() not in expires:
        if not options.quiet:
            print "Error: unknown expiry time. Valid values are (see --help):"
            print expires
        exit(1)

if not args:
    # read stdin until EOF
    lines = []
    for line in sys.stdin:
        lines.append(line)
        print line,
    add = {"api_paste_code":"".join(lines), "filename":"stdin"}
    if options.syntax:
        add["api_paste_format"] = options.syntax.lower()
    if options.name:
        add["api_paste_name"] = options.name
    targets = [add]

else:
    # read files from arguments
    targets = []
    for i in args:
        with open(i) as f:
            add = {"api_paste_code":f.read(), "filename":i}
            if (len(args) == 1) & (options.name != None):
                add["api_paste_name"] = options.name
            if options.syntax:
                add["api_paste_format"] = options.syntax.lower()
            else:
                add["api_paste_format"] = guess_syntax(os.path.splitext(i)[1])
            targets.append(add.copy())

if options.login:
    if not userkey:
        userkey = get_user_key()
else:
    userkey = "" # unset userkey


for target in targets:
    # make actual paste requests
    filename = target.pop("filename")
    target["api_dev_key"] = devkey
    target["api_option"] = "paste"
    if userkey:
        target["api_user_key"] = userkey
    if options.private:
        target["api_paste_private"] = "1"
    if options.expire:
        target["api_paste_expire_date"] = options.expire.upper()
    #print target
    try:
        req = urllib2.urlopen("http://pastebin.com/api/api_post.php", urllib.urlencode(target))
    except urllib2.URLError:
        if not options.quiet:
            print "Error uploading", filename + ":", "Network error"
        exit(2)
    else:
        reply = req.read()
        if "Bad API request" in reply:
            if not options.quiet:
                print "Error uploading", filename + ":", reply
            exit(2)
        else:
            if not options.quiet:
                print filename, "uploaded to:", reply
            else:
                print reply
