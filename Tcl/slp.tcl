# $Id$
#

###0 Buttes smeggdrop compatibility Tcl procs
if {[string length [info var tcl_interactive]]} {
  proc . args {join $args};
  proc nick {} {return "arab"};
  proc mask {} {return "arab@127.0.0.1"};
  proc or args {foreach value $args {if {$value ne ""} {return $value} }};
  proc last {list {count 1}} {if {$count == 1} {lindex $list end} else {lrange $list [- [llength $list] $count]]] end}};
  proc first list {lindex $list 0};
  proc lremove {list_var index} {upvar $list_var list; set list [lreplace $list $index $index]};
  proc ?? arges {lindex_random $arges};
  proc lindex_random {list {index -1}} {if {$index == -1} {set index [rand [llength $list]]}; lindex $list $index};
  proc rand {ceil args} {if [llength $args] {set floor $ceil; set ceil [first $args]} {set floor 0}; expr {int(rand()*($ceil-$floor)+$floor)}};
  proc faglame {} {lindex_random $::faglame_dict};
  proc lremove {list_var index} {upvar $list_var list; set list [lreplace $list $index $index]};
  set ::faglame_dict {gay faggot fag bum-fucker queer {ass bandit} {ass goblin} {ass pirate} {ass viking} poof buggerer {butt fucker} {butt pirate} catamite {cock sucker} {colon bomber} fairy fudge-packer homo tranny ladyboy limp-wrist pillow-biter queen sissy sissy-boy sodomite {spunk junkie} {turd burglar} twink poof {poo stabber} {uphill gardener} homosexual {Clinton supporter} {mac user} {out of the closet} {in the closet}};
};
###1
###0 Global variables, arrays, and messages
array unset slp%nick_db ; array unset slp%slp_db ; array unset slp:messages;

set slp:tm_fmt {%d/%m/%Y %H:%M:%S};
array set slp:messages [list                                                  \
SLP_BN          {${nick} went to slp at [clock format [clock seconds] -format ${::slp:tm_fmt}]}\
SLP_BM          {${nick} emoquit his slp at [clock format [clock seconds] -format ${::slp:tm_fmt}]}\
SLP_BM_NOT_ASLP {you're not even aslp you [?? {bloody fucking}] [faglame]}\
SLP_BN_IS_ASLP  {you're already aslp you [?? {bloody fucking}] [faglame]} \
SLP_SLP_NOENT   {nobody is aslp atm}                                          \
SLP_SLP_LINE    {${n}. ${nick} - aslp since [slp%tfmt0 ${bn}] ([slp%tfmt1 [expr [clock seconds] - ${bn}]])}\
SLP_SLP_LINE_BN {${n}. ${nick} - slpt from [slp%tfmt0 ${bn}] to [slp%tfmt0 ${bm}] ([slp%tfmt1 [expr ${bm} - ${bn}]])}\
SLP_SLP_NOENT2  {no slps recorded for ${nick}}
];
###1
###0 Slp wrapper proc(3TCL)s
proc slp%tfmt0 ts { global slp:tm_fmt ; clock format ${ts} -format ${slp:tm_fmt}; };
proc slp%tfmt1 clock {
  set units [list                                                             \
    [list [expr (12 * 30 * 24 * 60 * 60)] years]                              \
    [list [expr (30 * 24 * 60 * 60)]      months]                             \
    [list [expr (24 * 60 * 60)]           days]                               \
    [list [expr (60 * 60)]                hours]                              \
    [list [expr (60)]                     minutes]                            \
    [list [expr (1)]                      seconds]                            \
  ];

  if {([catch {set clock [expr int(${clock})]}]) || (0 >= ${clock})} {
    return 0;
  } else { set time ""; };

  while {0 != ${clock}} {
    set unit [first ${units}] ; set units [lrange ${units} 1 end];
    if {0 != [set n [expr ${clock} / [first ${unit}]]]} {
      lappend time [concat "[expr ${clock} / [first ${unit}]]" "[last ${unit}]"];
    }; set clock [expr ${clock} % [first ${unit}]];
  };

  if {1 < [llength ${time}]} {
    return [. [join [lrange ${time} 0 end-1] {, }], and [last ${time}]];
  } else { return [join ${time}]; };
}
###1
###0 Top-level interface proc(3TCL)s
proc bn {{nick {}} {mask {}}} {
  global slp:messages;

  catch "slp%add_slp bn [set nick [slp%get_nick [or ${mask} [mask]] [set nick [or ${nick} [nick]]]]]" msg;
  subst [set slp:messages(${msg})];
};

proc bm {{nick {}} {mask {}}} {
  global slp:messages;

  catch "slp%add_slp bm [set nick [slp%get_nick [or ${mask} [mask]] [set nick [or ${nick} [nick]]]]]" msg;
  subst [set slp:messages(${msg})];
};

proc slp {{nick {}}} {
  global slp%slp_db slp:messages ; set n 0 ; set out {};

  if {"" == ${nick}} {
    foreach nick [array names slp%slp_db] {
      if {(0 == [llength [set db [set slp%slp_db(${nick})]]])                 \
      ||  (0 == [expr [llength ${db}] % 2])} {
        continue;
      } else {
        incr n ; set bn [string range [lindex ${db} end] 3 end];
        lappend out "[subst [set slp:messages(SLP_SLP_LINE)]]";
      };
    };
  } else {
    if {0 == [llength [set db [last [array get slp%slp_db ${nick}]]]]} {
      subst [set slp:messages(SLP_SLP_NOENT2)];
    } else {
      foreach {bn bm} ${db} {
        incr n ; set bn [string range ${bn} 3 end];
        if {0 == [expr [llength ${db}] % 2]} {
          set bm [string range ${bm} 3 end] ; set msg SLP_SLP_LINE_BN;
        } else { set msg SLP_SLP_LINE; };
        lappend out "[subst [set slp:messages(${msg})]]";
      };
    };
  };

  join ${out} "\n";
};
###1
###0 Administrative proc(3TCL)s
proc slp:add_host {nick new_mask} {
  global slp%nick_db ; set found 0;
  foreach mask [array names slp%nick_db] { if {${nick} == [set slp%nick_db(${mask})]} { set found 1 ; break; }; };
  if {!${found}} { error "no such nick `${nick}'"; };
  set slp%nick_db(${new_mask}) ${nick};
};

proc slp:change_nick {nick nick2} {
  global slp%slp_db slp%nick_db;

  foreach mask [array names slp%nick_db] {
    if {${nick} == [set slp%nick_db(${mask})]} { set slp%nick_db(${mask}) ${nick2}; };
  };

  set slp%slp_db(${nick2}) [last [array get slp%slp_db ${nick}]];
  array unset slp%slp_db ${nick};
};

proc slp:merge {nick nick2} {
  global slp%slp_db slp%nick_db ; set nslp 0 ; set nmasks 0;
  set db [last [array get slp%slp_db ${nick}]] ; set db2 [last [array get slp%slp_db ${nick2}]];

  if {0 == [llength ${db}]} { error "no such nick `${nick}'"; }               \
  elseif {0 == [llength ${db2}]} { error "no such nick `${nick2}'"; }         \
  else {
    #
    # Forcefully end ongoing slp of either nicks to simplify the below logic.
    if {1 == [string match "bn:*" [last ${db}]]} { lappend db bm:[clock seconds]; };
    if {1 == [string match "bn:*" [last ${db2}]]} { lappend db2 bm:[clock seconds]; };

    #
    # Iteratively insert each slp within the second source slp list into the
    # first target slp list in between bm and bn timespans, ignoring slp entries
    # from the former not falling into free bm-bn ranges.
    while {0 != [llength ${db2}]} {
      set out 0;

      for {set n 0} {${n} < [llength ${db2}]} {incr n 2} {
        set bn2 [string range [lindex ${db2} ${n}] 3 end];
        set bm2 [string range [lindex ${db2} [expr 1 + ${n}]] 3 end];

        for {set m -2} {${m} < [expr 2 + [llength ${db}]]} {incr m} {
          set bm1 [or [string range [lindex ${db} [expr 1 + ${m}]] 3 end] -1];
          set bn1 [or [string range [lindex ${db} [expr 2 + ${m}]] 3 end] -1];

          if {((-1 == ${bm1}) || (${bn2} >= ${bm1}))
          &&  ((-1 == ${bn1}) || (${bm2} <= ${bn1}))} {
            set db [linsert ${db} [expr 2 + ${m}] bn:${bn2} bm:${bm2}] ; incr nslp ; set out 1 ; break;
          };
        };

        lremove db2 ${n} ; lremove db2 ${n}; if {${out}} { break; };
      };
    };
  };

  #
  # Update the nick name for masks still mapping the second nick name
  # corresponding to the second source slp list now merged with the first
  # target slp list.
  foreach mask [array names slp%nick_db] {
    if {${nick2} == [last [array get slp%nick_db ${mask}]]} {
      set slp%nick_db(${mask}) ${nick} ; incr nmasks;
    };
  };

  #
  # Update the slp database array entry and return back to the caller with
  # informational statistics.
  set slp%slp_db(${nick}) ${db} ; unset slp%slp_db(${nick2});
  return "merged ${nslp} slp entries and ${nmasks} masks, new `${nick}' list length: [expr [llength ${db}] / 2]";
};
###1
###0 Internal proc(3TCL)s
proc slp%get_nick {mask {nick {}}} {
  global slp%nick_db;

  if {0 == [llength [last [array get slp%nick_db ${mask}]]]} {
    if {"" == ${nick}} { error "missing nick for mask=${mask}"; }             \
    else { set slp%nick_db(${mask}) ${nick}; };
  }; set slp%nick_db(${mask});
};

proc slp%add_slp {type nick} {
  global slp%slp_db;

  #
  # If bn'ing, append bn:<ts> given no prior slp entries or no ongoing bn.
  if {(0 == [llength [set db [last [array get slp%slp_db ${nick}]]]])         \
   ||  (1 == [string match "bm:*" [last ${db}]])} {
    if {"bn" == ${type}} {
      lappend slp%slp_db(${nick}) bn:[clock seconds] ; return SLP_BN;
    } else { error SLP_BM_NOT_ASLP; };

  #
  # If bm'ing, append bm:<ts> given prior slp entries and an ongoing bn.
  } elseif {1 == [string match "bn:*" [last ${db}]]} {
    if {"bm" == ${type}} {
      lappend slp%slp_db(${nick}) bm:[clock seconds] ; return SLP_BM;
    } else { error SLP_BN_IS_ASLP; };
  } else { error "inconsistency in slp_db: [last ${db}]"; };
};
###1

# vim:ts=2 sw=2 expandtab filetype=tcl
# vim:foldmethod=marker foldmarker=\#\#\#0,\#\#\#1 fileencoding=utf-8
