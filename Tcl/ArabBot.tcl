#! /bin/sh
# -*- tcl -*- \
exec tclsh8.4 "$0" ${1+"$@"}

package require tls
package require irc
package require Tclx
package require http 2.5
package require md5

set cn [::irc::connection]
set nick f1re
lappend channels "#arab"
set trigger tcl
set lastsave [clock seconds]
set invoketarget ""
set who ""
set http_timeout 2
set wordslist /usr/share/dict/words
array set nicks {}

proc lindex_random {mylist} {
	return [lindex $mylist [expr [join [list {int(rand()*[llength $mylist])}]]]]
}

proc Connect {} {
	global cn nick
	namepace eval [lrange [regexp -inline {^(.+?)::network$} $cn] end end] {
		proc cmd-connect { h {p 6667} } {
			variable sock; variable host; variable port
			set host $h; set port $p

			if {$sock == ""} {
				set sock [::tls::socket $host $port]
				fconfigure $sock -translation crlf -buffering line
				fileevent $sock readable [namespace current]::GetEvent
			}; return 0;
		}
	}

	$cn connect irc.arabs.ps 6667
	$cn user "f1re" localhost domain "vxp's Tcl Bint"
	$cn nick $nick
}

set last_command ""
set last_command_time 0
set body ""

proc enforce_limits command {
	global last_command last_command_time http_timeout
    
	set difference [expr ([clock clicks -milliseconds] - $last_command_time)/1000.0]
    	if {$difference > $http_timeout} return
	if {$last_command eq "head"} {
		if {!($command eq "head")} {return}
	}
	#error "Can't use HTTP for [expr $http_timeout-$difference] more seconds"
}

proc update_limits command {
	global last_command last_command_time
	
	set last_command $command
	set last_command_time [clock clicks -milliseconds]
}

proc http_proc {name args body} {
	set new_body [list]
	lappend new_body [list enforce_limits $name]
	lappend new_body "if {\[catch [list $body] {}] == 1} {error \[set {}]}"
	lappend new_body [list update_limits $name]
	lappend new_body [list set {}]
	set new_body [join $new_body \;]
	proc $name $args $new_body
}

proc http_read_progress_callback {token total current} {
	upvar #0 $token state
	if {$current > 5512000} {http::reset $token "transfer exceeded 512000 bytes"}
}

proc http_handle_token token {
	upvar #0 $token state
	
	set status $state(status)
	
	if {!($status eq "ok")} {
	    http::cleanup $token
	    error $status
	}
	
	set ret [list]
	lappend ret [http::ncode $token]
	lappend ret $state(meta)
	lappend ret $state(body)
	http::cleanup $token
	return $ret
}

http_proc head url {
	set token [http::geturl $url -timeout 15000 -validate 1]
	http_handle_token $token
}

http_proc get {url args} {
	set token [http::geturl $url -binary true -timeout 15000 -blocksize 1024 -progress http_read_progress_callback -headers $args]
	http_handle_token $token
}

http_proc post {url body args} {
	if [llength $args] {set body [eval http::formatQuery [concat [list $body] $args]]}
	
	if {[string length $body] > 2256000} {error "query exceeds 2256000 bytes"}
	
	set token [http::geturl $url \
	    -timeout   5000 \
	    -blocksize 1024 \
	    -progress  http_read_progress_callback \
	    -query     $body]
	
	http_handle_token $token
}

proc put_proc {proc} {
	set file "";
        append file "proc [list $proc] {\n"
        set space ""
        foreach i [slave eval info args $proc] {
            if [slave eval info default $proc $i tcl_defaultvalue] {
                set value [slave eval set tcl_defaultvalue]
                append file "$space{$i [list $value]}\n"
                slave eval unset tcl_defaultvalue
            } else {
                append file "$space$i\n"
            }
            set space " "
        }
        append file "} {[slave eval info body $proc]}\n"
	return $file;
}
proc put_var {i} {
	set file "";
	if {$i == "env"} return ;
	if {[string match tcl_* $i]} return ;
	if {[string match auto_index $i]} return ;
	if {$i eq "errorCode" || $i eq "errorInfo"} return;
	if {[slave eval array exists ::$i]} {
	    append file "[list array set $i [slave eval array get ::$i]]\n"
	} else {
	    append file "[list set $i [slave eval set ::$i]]\n"
	}
	return $file;
}
proc put_var_out {i file} {
	set o [eval put_var $i];
	if {$o ne ""} {
		puts $file $o;
	}
}
proc put_proc_out {proc file} {
    	set o [eval put_proc $proc];
	if {$o ne ""} {
		puts $file $o;
	}
}
proc interp_dump {filename} {
	puts "[clock format [clock seconds]]: Saving State, please hold...."
	set file [open $filename w]
	
	puts $file "\# slave state dump: [clock format [clock seconds]]\n"
	
	foreach "proc" [lsort [slave eval info procs]] {
		if {[catch { put_proc_out $proc $file }]} {
			puts stderr "Saving of PROC $proc FAILED";
		}
	}
	
	foreach i [lsort [slave eval info globals]] {
		if {[catch { put_var_out $i $file; }]} {
			puts stderr "Saving of VAR $i FAILED";
		}
	}
	
	close $file
}

proc check_time {since limit} {
	if {[clock clicks -milliseconds] - $since > $limit} {
		error "maximum execution time of $limit ms reached"
	}
}

#safe replacement commands for the slave
proc r_eval {script} {
	# set up the time-check alias
	signal error SIGALRM
	alarm 5.5
	slave alias _safe_check_time check_time [clock clicks -milliseconds] 15000
	# evaluate and return
	set ret [slave eval $script]
	alarm 0
	signal ignore SIGALRM
	return $ret
}
proc r_after {args} {
	set time [lindex $args 0]
	if [regexp {^[[:digit:]]+$} $time] {
		error "can't call \"after\" with integer time: unsafe"
	}
	eval "slave invokehidden _unsafe_after $args"
}
proc r_while {test body} {
	set body "_safe_check_time\n$body"
	slave invokehidden _unsafe_while $test $body
}
proc r_for {init test pre body} {
	set body "_safe_check_time\n$body"
	slave invokehidden _unsafe_for $init $test $pre $body
}
proc r_proc {name argv body} {
	if [string eq $name "_safe_check_time"] {
		error "can't override \"_safe_check_time\": unsafe"
	}
	slave invokehidden _unsafe_proc $name $argv $body
}

proc r_namespace {cmd args} {
	if [string match "$cmd*" "delete"] {
		set name [lindex $args 0]
		::catch {slave invokehidden _unsafe_namespace parent $name} parent
		if [string eq $parent [list]] {
			error "can't delete root namespace: unsafe"
		}
	}
	eval "slave invokehidden _unsafe_namespace $cmd $args"
}
proc r_rename {name newname} {
	if [string eq $name "_safe_check_time"] {
		error "can't rename \"_safe_check_time\": unsafe"
    	}
	slave invokehidden _unsafe_rename $name $newname
}
proc r_catch {script {setit "errorInfo"}} {
	set msg "SIGALRM signal received"
	set out [::catch { slave eval $script } errMsg]
	if {[string equal $errMsg $msg]} {
		error $msg
	}
	slave eval uplevel 0 [list set $setit [list $errMsg]]
	return $out
}
#
#commands aliased to the slave interpreter
proc channel {} {
	global invoketarget
	return $invoketarget
}

proc name {{who ""}} {
	global nicks invoketarget
	if {$who != ""} { return $who }
	if {[array names nicks $invoketarget] != ""} {
		return [lindex_random $nicks($invoketarget)]
	} else {
		error "could not find channel array for $invoketarget"
	}
}

proc names {} {
	global nicks invoketarget
	if {[array names nicks $invoketarget] != ""} {
		return [join $nicks($invoketarget) " "]
	} else {
		error "could not find channel array for $invoketarget"
	}
}

proc save_state {} {
	doSave
}

proc nick {} {
	global who
	return $who
}

proc http {method url args} {
	if {$method != "get" && $method != "head" && $method != "post"} {error "Invalid HTTP command"}
	if {[catch {eval $method $url $args} retval] == 0} {
		return $retval
	} else {
		error $retval
	}

}

proc word {} {
	global wordslist
	if {[catch {open $wordslist} fh] == 0} {
		set data [read $fh]
		close $fh
		return [lindex_random $data]
	} else {
		error "Error opening $wordslist"
	}
}

puts "TCL version: [info patchlevel]"
puts "Loading state data into safe interpreter..."
encoding system utf-8
interp create -safe slave
foreach procname {after for while proc namespace catch rename} {
	slave eval rename $procname _unsafe_$procname
	slave hide _unsafe_$procname
        slave alias $procname r_$procname
}
slave hide interp
slave hide vwait

interp invokehidden slave source state.dat
slave alias http2 http::geturl
slave alias http http
slave alias http_config http::config
slave alias nick nick
slave alias names names
slave alias name name
slave alias channel channel
slave alias word word
slave alias macro doMacro
slave alias macros doMacros
slave alias save_state doSave2
slave alias say2 doMsg
slave alias md5sum ::md5::md5
slave alias fchans file channels
slave alias encoding encoding
puts "[clock format [clock seconds]]: Connecting to IRC..."
Connect

proc doSave {} {
	global lastsave
	set currenttime [clock seconds]
	if {[expr ($currenttime - $lastsave) > 3600]} {
		interp_dump state.dat
		set lastsave $currenttime 
	}
}

proc doSave2 {} {
	interp_dump state.dat
}


signal trap SIGINT {
	signal ignore SIGINT
	$cn quit "lopl"
	interp_dump state.dat
	exit
}

$cn registerevent defaultcmd {
	doSave
	#puts "cmd who: [who] action: [action] target: [target] additional: [additional]"
	#puts "cmd header: [header] msg: [msg]"
}

$cn registerevent defaultnumeric {
	doSave
	#puts "numeric who: [who] action: [action] target: [target] additional: [additional]"
	#puts "numeric header: [header] msg: [msg]"
}

$cn registerevent defaultevent {
	doSave
	#puts "event who: [who] action: [action] target: [target] additional: [additional]"
	#puts "event header: [header] msg: [msg]"
}

$cn registerevent KICK {
	doSave
	global nicks
	set mynicks [list]
	foreach nick $nicks([target]) {
		if {$nick == [additional]} {
			continue;
		}
		lappend mynicks $nick
	}
	set nicks([target]) $mynicks
}
$cn registerevent NICK {
	doSave
	global nicks
	foreach chan [array names nicks] {
		set mynicks [list]
		foreach nick $nicks($chan) {
			if {$nick == [who]} {
				lappend mynicks [msg]
				continue;
			}
			lappend mynicks $nick
		}
		set nicks($chan) $mynicks
	}
}

$cn registerevent QUIT {
	doSave
	global nicks
	foreach chan [array names nicks] {
		set mynicks [list]
		foreach nick $nicks($chan) {
			if {$nick == [who]} {
				continue;
			}
			lappend mynicks $nick
		}
		set nicks($chan) $mynicks
	}
}

$cn registerevent PART {
	doSave
	global nicks
	set mynicks [list]
	foreach nick $nicks([target]) {
		if {$nick == [who]} {
			continue;
		}
		lappend mynicks $nick
	}
	set nicks([target]) $mynicks
}


$cn registerevent JOIN {
	doSave
	global nicks
	lappend nicks([msg]) [who]
}

$cn registerevent 353 {
	doSave
	global nicks

	set chan [string range [additional] 2 end]
	foreach nick [split [msg] " "] {
		set nick [string trimleft $nick @]
		set nick [string trimleft $nick ~]
		set nick [string trimleft $nick +]
		if {$nick == ""} { continue }
		if {[lsearch -exact $nicks($chan) $nick] > -1} { continue }
		lappend nicks($chan) $nick
	}
}

$cn registerevent 001 {
        puts "Connected"
        global cn channels
	foreach chan $channels {
		$cn join $chan
	}
}

proc splitMessage {input target {max 5000}} {
	global cn
	set i 0
	#first split - split by line
	foreach line [split $input \n] {
		#second split - split by maximum line length
		set index 0
		set maxlen 420
		while {1} {
			if {$i == $max} {
				$cn privmsg $target "maximum number of lines ($max) exceeded. output truncated"
				return
			}
			incr i
			$cn privmsg $target [string range $line $index [expr $index+$maxlen]]
			set inTime [clock clicks -milliseconds]
			while {[clock clicks -milliseconds] - $inTime < 550} { }
			set index [expr $index+$maxlen+1]
			if {$index > [string length $line]} {
				break
			}
		}
	}
}

proc doMsg {what target} {
	splitMessage $what $target
}

proc replaceWithNick {text} {
	if {[string first "%s" $text] == -1} {return $text}
	set index [string first "%s" $text]
	return "[string range $text 0 [expr $index-1]][name][string range $text [expr $index+2] end]"
}

$cn registerevent PRIVMSG {
	doSave
	global cn channels trigger nick invoketarget who
	set invoketarget [target]; set who [who]

    	if {[string tolower [target]] == [string tolower $nick]} { return };
	
	if {[regexp -nocase {^(?:[@!^:.xv>n=.;sl<o>pu;+?akh]|lo)} [msg]]} {
		if {[string equal [msg] "!macros"]} {
			set data [doMacros];
			catch {splitMessage $data [target]}
		}

		set files [glob ascii/*]
		if {[string equal [msg] "!macro"] || [string equal [msg] "@rand"]} {
			set file [lindex $files [expr [join [list {int(rand()*[llength $files])}]]]]
			set file [string range $file 6 end]
			catch {splitMessage "@$file" [target]}
			set file "ascii/$file"
		} else {
			set data [doMacro [msg]];
			catch {splitMessage $data [target] 99999}
		}
	}

	if {[string range [msg] 0 [expr [string length $trigger]-1]] != $trigger} {
		return
	}

	set reqcmd [string range [msg] [expr [string length $trigger]+1] end]
	set results ""
	catch {r_eval $reqcmd} results
	catch {splitMessage $results [target]}
}

proc doMacro {msg} {
	set file [string map {{ } {_} {;} {:} {?} {Q} {]} {br}} [string range $msg 1 end]]
	if {[catch {set file [glob ascii/$file]}] != 0} { return; }
	if {[file isfile $file] != 1} { return; }

	enforce_limits macro
	if {[catch {open $file} fh] == 0} {
		set data [read $fh]
		set data [replaceWithNick $data]
		close $fh
	}
	update_limits macro

	return $data
}

proc doMacros {} {
	set files [glob ascii/*]; set line {};
	while {[llength $files] > 0} {
		lappend line [regsub -all "ascii/" [join [lrange $files 0 10] " "] "@"]
		set files [lrange $files 11 end]
	}

	return [join $line]
}

::http::config -useragent {Mozilla/5.0 (Windows; U; Windows NT 5.1; de; rv:1.9.0.3) Gecko/2008092417 Firefox/3.0.3}
vwait forever
