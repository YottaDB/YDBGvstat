; My current version of this code is published at https://github.com/ksbhaskar/Demo/gvstat.m
; No claim of copyright is made with regard to this demonstration code; adapt the ideas herein to your specific requirements.
; If you fix bugs, or enhance it to be generally more useful vs. adapting it to your specific needs, please do e-mail
; your changes to bhaskar@bhaskars.com (or send a Github pull request), disclaiming any copyright, and I will consider including them.
;
; K.S. Bhaskar
;
; Revision History:
; Version  Date                Author                            Summary
;   0.1    April 6, 2017       K.S. Bhaskar                      Original version
;
gvstat
	; Utility program to demonstrate gathering and using GT.M database statistics
	; Usage: mumps -run $text(+0) [options] where [options] is zero or one of:
	; --consume - read lines of stdin ($PRINCIPAL) whose format is <region>,$horolog,$view("gvstat",<region>) and store into database
	; --csvdump - dump all statistics in database in csv format to stdout
	; --csvout [suboptions] - output selected statistics from database in csv format to stdout, where [suboptions] are:
	;   --date fromdate[,todate] - inclusive range of dates, in formats accepted by $$FUNC^%DATE except those using commas
	;     todate defaults to fromdate; omit suboption to select all dates in database
	;   --reg "*"|reg[,reg...] - comma separated list of regions, "*" or omit for all regions
	;   --stat "*"|stat[,stat...] - comma separated list of statistics, "*" or omit for all statistics
	;   --time fromtime[,totime] - inclusive range of times in selected dates, in format accepted by $$FUNC^%TI
	;     omitted fromtime defaults to 00:00:00, omitted totime defaults to 23:59:59
	; --gatherdb [suboptions] - gather statistics and store in a database, where [suboptions] are:
	;   --gld globaldirectoryfile - global directory for database in which to store statistics, defaults to $gtmgbldir
	;   --int interval - interval in seconds between gatherings (program runs until terminated), defaults to 60 seconds
	;     interval of 0 means gather statistics once and terminate
	; --gatherfile [suboptions] - gather statistics and produce files that can later be read by --consume, where [suboptions] are:
	;   --fname filenamepattern - pattern for output file; filenamepattern shoud end in "_pattern" where pattern is
	;     a format recognized by $ZDATE(), to generate a timestamp for the file open time. If missing, defaults to
	;     "_YEAR-MM-DD+24:60:SS". When closing a file, a "-pattern" timestamp is appended to the filename as a closing timestamp.
	;   --int interval - interval in seconds between gatherings (program runs until terminated), defaults to 60 seconds
	;     interval of 0 means gather statistics once and terminate
	;   --rolltod is a time of day at which to switch the output file; use format recognized by %TI
	;     if time of day is a number representing seconds since midnight, quote it
	;   --rolldur is a duration/lifetime in seconds for each file
	;   If both rolldur and rolltod are specified, file is switched when either event happens.
	;   If neither is specified, output file is never switched.
	; --help - print information on using the program; default option if none specified
	; When storing database statistics, compute and store the ratio of lock failures (LKF) to successes (LKS).
	; If gathered statistics include critical section acquisition data, compute and store acquisition statistics.
	; Invoke from other programs using the following entryrefs:
	;   do consume^$text(+0)
	;   do csvout^$text(+0)(reg,date,time,stat)
	;   do csvdump^$text(+0)
	;   do gatherdb^$text(+0)(gld,int)
	;   do gatherfile^$text(+0)(fname,int,rolltod,rolldur)
	;   do help^$text(+0)
	; Caution: this program assumes GT.M short circuting of expressions; compile accordingly.

	use $principal:(ctrap=$char(3):nocenable:exception="halt")	   ; terminate on Ctrl-C if invoked from shell
	set $etrap="set $etrap=""use $principal write $zstatus,! zhalt 1"""
	set $etrap=$etrap_" set tmp1=$piece($ecode,"","",2),tmp2=$text(@tmp1)"
	set $etrap=$etrap_" if $length(tmp2) write $text(+0),@$piece(tmp2,"";"",2,$length(tmp2,"";"")),!"
	set $etrap=$etrap_" do help zhalt +$extract(tmp1,2,$length(tmp1))"
	set:$stack $ecode=",U254,"	; top level entryref can only be invoked from the shell
	new cmdline,date,fname,gld,int,reg,rolldur,rolltod,stat,time
	set cmdline=$select($length($zcmdline):$zcmdline,1:"--help")
	for  quit:'$$trimleadingstr^%XCMD(.cmdline,"--")  do ; process options
	. if $$trimleadingstr^%XCMD(.cmdline,"consume") do consume quit
	. else  if $$trimleadingstr^%XCMD(.cmdline,"csvout") do  do csvout($get(reg),$get(date),$get(time),$get(stat)) quit
	. . do trimleadingstr^%XCMD(.cmdline," ")
	. . for  quit:'$$trimleadingstr^%XCMD(.cmdline,"--")  do
	. . . if $$trimleadingstr^%XCMD(.cmdline,"date") set date=$$trimleadingdelimstr^%XCMD(.cmdline)
	. . . else  if $$trimleadingstr^%XCMD(.cmdline,"reg") set reg=$$trimleadingdelimstr^%XCMD(.cmdline)
	. . . else  if $$trimleadingstr^%XCMD(.cmdline,"stat") set stat=$$trimleadingdelimstr^%XCMD(.cmdline)
	. . . else  if $$trimleadingstr^%XCMD(.cmdline,"time") set time=$$trimleadingdelimstr^%XCMD(.cmdline)
	. . . else  set $ecode=",U248,"
	. . . do trimleadingstr^%XCMD(.cmdline," ")
	. else  if $$trimleadingstr^%XCMD(.cmdline,"csvdump") do csvdump quit
	. else  if $$trimleadingstr^%XCMD(.cmdline,"gatherdb") do  do gatherdb($get(gld),$get(int)) quit
	. . do trimleadingstr^%XCMD(.cmdline," ")
	. . for  quit:'$$trimleadingstr^%XCMD(.cmdline,"--")  do
	. . . if $$trimleadingstr^%XCMD(.cmdline,"gld") set gld=$$trimleadingdelimstr^%XCMD(.cmdline)
	. . . else  if $$trimleadingstr^%XCMD(.cmdline,"int") set int=$$trimleadingdelimstr^%XCMD(.cmdline)
	. . . else  set $ecode=",U247,"
	. . . do trimleadingstr^%XCMD(.cmdline," ")
	. else  if $$trimleadingstr^%XCMD(.cmdline,"gatherfile") do  do gatherfile($get(fname),$get(int),$get(rolltod),$get(rolldur)) quit
	. . do trimleadingstr^%XCMD(.cmdline," ")
	. . for  quit:'$$trimleadingstr^%XCMD(.cmdline,"--")  do
	. . . if $$trimleadingstr^%XCMD(.cmdline,"fname") set fname=$$trimleadingdelimstr^%XCMD(.cmdline)
	. . . else  if $$trimleadingstr^%XCMD(.cmdline,"int") set int=$$trimleadingdelimstr^%XCMD(.cmdline)
	. . . else  if $$trimleadingstr^%XCMD(.cmdline,"rolldur") set rolldur=$$trimleadingdelimstr^%XCMD(.cmdline)
	. . . else  if $$trimleadingstr^%XCMD(.cmdline,"rolltod") set rolltod=$$trimleadingdelimstr^%XCMD(.cmdline)
	. . . else  set $ecode=",U246,"
	. . . do trimleadingstr^%XCMD(.cmdline," ")
	. else  if $$trimleadingstr^%XCMD(.cmdline,"help") do help quit
	. else  set $ecode=",U249,"
	. do trimleadingstr^%XCMD(.cmdline," ")
	quit

consume	for   read line quit:$zeof  do:$length(line,",")-1 digest(line)
	quit

csvout(reg,date,time,stat)
	new d,dt,fromdate,fromtime,maxdt,mindt,t,todate,totime
	set reg=$get(reg) if "*"=reg!'$length(reg) set (r,reg)=$order(^gvstatinc("")) for  set r=$order(^gvstatinc(r)) quit:""=r  set reg=reg_","_r
	set date=$get(date)
	set:$length(date) fromdate=$$FUNC^%DATE($piece(date,",",1)),todate=$select($length(date,",")-1:$$FUNC^%DATE($piece(date,",",2)),1:fromdate)
	set time=$get(time) if ""=time set fromtime=0,totime=86399
	else  set time=$get(time),fromtime=$$FUNC^%TI($piece(time,",",1)),totime=$select($length(time,",")-1:$$FUNC^%TI($piece(time,",",2)),1:$select(fromtime:fromtime+59,1:86399))
	set stat=$get(stat) do:"*"=stat!'$length(stat)
	. set r=$order(^gvstatinc("")),dt=$order(^gvstatinc(r,"")),(s,stat)=$order(^gvstatinc(r,dt,""))
	. for  set s=$order(^gvstatinc(r,dt,s)) quit:""=s  set stat=stat_","_s
	write "REGION,DATE,TIME,",stat,!
	set mindt=+$get(fromdate)*86400+fromtime-1,maxdt=$select($length($get(todate)):+todate,1:$piece($horolog,",",1))*86400+totime
	for i=1:1:$length(reg,",") set r=$piece(reg,",",i) do:$data(^gvstatinc(r))
	. set dt=mindt for  set dt=$order(^gvstatinc(r,dt)) quit:""=dt!(dt>maxdt)  set d=dt\86400,t=dt#86400 do:t>=fromtime&(t<=totime)
	. . write r,",",$zdate(d_","_t,"YEAR-MM-DD,24:60:SS")
	. . for j=1:1:$length(stat,",") set s=$piece(stat,",",j) write ",",$get(^gvstatinc(r,dt,s))
	. . write !
	quit

csvdump	; dump the entire ^gvstatinc global in csv format
	set reg=$order(^gvstatinc("")),daytime=$order(^gvstatinc(reg,""))
	write "REGION,DATE,TIME,"
	set (stat,tmp)="" for  set stat=$order(^gvstatinc(reg,daytime,stat)) write:$length(stat) stat,"," if ""=stat write ! quit
	write $extract(tmp,1,$length(tmp-1))
	set reg="" for  set reg=$order(^gvstatinc(reg)) quit:""=reg  do
	. set daytime="" for  set daytime=$order(^gvstatinc(reg,daytime)) quit:""=daytime  write reg,",",$zdate(daytime\86400_","_(daytime#86400),"YEAR-MM-DD,24:60:SS") do
	. . set stat="" for  set stat=$order(^gvstatinc(reg,daytime,stat)) write:$length(stat) ",",^gvstatinc(reg,daytime,stat) if ""=stat write ! quit
	quit

digest(line)
	; line format expected is <region>,$horolog,$view("gvstat",<region>), so statistics start at 4th comma separated piece
	new daytime,j,prevtime,reg,stat,tmp,val
	set reg=$piece(line,",",1)
	set daytime=$piece(line,",",2)*86400+$piece(line,",",3)
	set prevtime=+$order(^gvstat(reg,daytime),-1)
	for j=4:1:$length(line,",") do
	. set tmp=$piece(line,",",j),stat=$piece(tmp,":",1),val=$piece(tmp,":",2)
	. set ^gvstat(reg,daytime,stat)=val
	. set:prevtime ^gvstatinc(reg,daytime,stat)=val-^gvstat(reg,prevtime,stat)
	do:prevtime    ; compute derived statistics
	. set ^gvstatinc(reg,daytime,"LKfrate")=$select(^("LKS"):^("LKF")/^("LKS"),1:$select(^("LKF"):999999999999999999,1:"")) ; LKF=nonzero+LKS=0 is infinite fail rate
	. set n=$get(^gvstatinc(reg,daytime,"CAT"),0)	; older versions of GT.M may not have CAT et al to compute derived statistics, also CAT may be zero
	. if n do	; naked references used to make code fit on one line; none relied on outside a line
	. . set a=^gvstatinc(reg,daytime,"CFT"),b=^("CFS"),(avg,^("CFavg"))=a/n,(sigma,^("CFsigma"))=((b+(avg*(n*avg-(2*a))))/n)**.5,^("CFvar")=$select(sigma:sigma/avg,1:"")
	. . set a=^gvstatinc(reg,daytime,"CQT"),b=^("CQS"),(avg,^("CQavg"))=a/n,(sigma,^("CQsigma"))=((b+(avg*(n*avg-(2*a))))/n)**.5,^("CQvar")=$select(sigma:sigma/avg,1:"")
	. . set a=^gvstatinc(reg,daytime,"CYT"),b=^("CYS"),(avg,^("CYavg"))=a/n,(sigma,^("CYsigma"))=((b+(avg*(n*avg-(2*a))))/n)**.5,^("CYvar")=$select(sigma:sigma/avg,1:"")
	. else  set (^gvstatinc(reg,daytime,"CFavg"),^("CFsigma"),^("CFvar"),^("CQavg"),^("CQsigma"),^("CQvar"),^("CYavg"),^("CYsigma"),^("CYvar"))=""
	quit

donefile
	; on interrupt, clean up file used for gathering data and exit
	new tmp
	set tmp=$zdate($horolog,pattern)
	close outfile:rename=outfile_"_to_"_tmp
	lock -^gvstat($job)
	quit

gatherdb(gld,int)
	; gather statistics from current database into a database specified by gld
	; int is an interval in seconds between runs, defaulting to 60
	;   if int is zero gathers statistics just once and quits
	; using ^%PEEKBYNAME() would be more efficient than using $view("gvstat",<region>), but the difference is not
	; material for code that runs at most once every tens of seconds
	lock +^gvstat($job)
	lock +^gvstat:0 if  lock -^gvstat
	else  write "Note: another gvstat process is already running",!
	new nextint,reg,savegd,zint
	set int=$select($length($get(int)):+$get(int),1:60)*1E6	; convert to microseconds for compatibility with $ZUT
	set savegd=$zgbldir
        set zint=$zinterrupt,$zinterrupt="set $zinterrupt=zint,int=0"
	set nextint=$zut+int
	for  do:$increment(nextint,int)  quit:'int  do
	. set reg="" for  set reg=$view("gvnext",reg) quit:""=reg  do digest(reg_","_$horolog_","_$view("gvstat",reg))
	. hang nextint-$zut/1E6
	lock -^gvstat($job)
	quit

gatherfile(fname,int,rolltod,rolldur)
	; gather statistics and output to a file
	lock +^gvstat($job)
	lock +^gvstat:0 if  lock -^gvstat
	else  write "Note: another gvstat process is already running",!
	new nextdur,nextint,nexttod,outfile,patlen,pattern,tmp,tmp1,zint,zut
	set patlen=$length(fname,"_") set:patlen<2 fname=fname_"_YEAR-MM-DD+24:60:SS",patlen=2
	set pattern=$piece(fname,"_",patlen),outfile=$piece(fname,"_",1,patlen-1)_"_"_$zdate($horolog,pattern)
	set int=$select($length($get(int)):+$get(int),1:60)*1E6	; convert to microseconds for compatibility with $ZUT
	set rolldur=+$get(rolldur) set rolldur=$select(0>rolldur:0,1:rolldur*1E6)
	set rolltod=$get(rolltod)  ; rolltod may not be numeric
	if rolltod!$length(rolltod) do
	. set rolltod=$$FUNC^%TI(rolltod)
	. set tmp=$horolog,tmp1=rolltod-$piece(tmp,",",2) if 0>tmp1&$increment(tmp1,86400)
	. set rolltod=tmp1*1E6
	else  set rolltod=0
        set zint=$zinterrupt,$zinterrupt="set $zinterrupt=zint zgoto "_$zlevel_":donefile"
	open outfile:newver use outfile
	set (nextint,zut)=$zut,nextdur=$select(rolldur:zut+rolldur,1:0),nexttod=$select(rolltod:zut+rolltod,1:0)
	for  do:$increment(nextint,int)  if 'int do donefile quit
	. set reg="" for  set reg=$view("gvnext",reg) quit:""=reg  write reg,",",$horolog,",",$view("gvstat",reg),!
	. do:nextdur&(nextdur<nextint&$increment(nextdur,rolldur))!(nexttod&(nexttod<nextint&$increment(nexttod,86400*1E6)))
	. . set tmp=$zdate($horolog,pattern)
	. . close outfile:rename=outfile_"_to_"_tmp
	. . set outfile=$piece(fname,"_",1,patlen-1)_"_"_tmp
	. . open outfile:newver use outfile
	. hang nextint-$zut/1E6
	quit

help	new j,k,label,tmp
	set label=$text(+0)
	for j=1:1 set tmp=$piece($text(@label+j),"; ",2) quit:""=tmp  do
	. write $piece(tmp,"$text(+0)",1) for k=2:1:$length(tmp,"$text(+0)") write $text(+0),$piece(tmp,"$text(+0)",k)
	. write !
	quit

;	Error message texts
U246	;"-F-ILLGATHERFILOPT Illegal suboption for --getherfile starting with: --"_cmdline
U247	;"-F-ILLGATHERDBOPT Illegal suboption for --gatherdb starting with: --"_cmdline
U248	;"-F-ILLCSVOUTOPT Illegal suboption for --csvout option starting with: --"_cmdline
U249	;"-F-ILLCMDLINE Illegal command line starting with: --"_cmdline
U254	;"-F-LABREQ Invocation from another program must specify a label;  use mumps -run "_$text(+0)_" to execute from top of routine"