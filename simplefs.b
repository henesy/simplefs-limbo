implement SimpleFS;

include "sys.m";
	sys: Sys;
	sprint, print, fildes: import sys;
	OTRUNC, ORCLOSE, OREAD, OWRITE: import Sys;

include "draw.m";

include "arg.m";

include "styx.m";
	styx: Styx;
	Tmsg, Rmsg: import Styx;

include "styxservers.m";
	styxservers: Styxservers;
	Styxserver, Fid, Navigator,
	Navop, Enotfound, Enotdir: import styxservers;

SimpleFS: module {
	init: fn(nil: ref Draw->Context, argv: list of string);
};

# FS file index
Qroot, Qctl, Qlog, Qmax: con iota;
tab := array[] of {
	(Qroot, ".", Sys->DMDIR|8r555),
	(Qctl, "ctl", 8r222),
	(Qlog, "log", 8r444),
};

user: string	= "none";		# User owning the fs
chatty: int		= 0;			# Debug log toggle -- triggers styx(2) tracing
log: list of string;			# Written log history

# Serves a simple read-write filesystem 
init(nil: ref Draw->Context, argv: list of string) {
	sys = load Sys Sys->PATH;
	arg := load Arg Arg->PATH;
	if(arg == nil)
		raise "could not load arg";
	styx = load Styx Styx->PATH;
	if(styx == nil)
		raise "could not load styx";
	styxservers = load Styxservers Styxservers->PATH;
	if(styxservers == nil)
		raise "could not load styxservers";

	chatty = 0;

	arg->init(argv);
	arg->setusage("simplefs [-D] [-u user]");

	while((c := arg->opt()) != 0)
		case c {
		'D' =>
			chatty++;

		'u' =>
			user = arg->earg();

		* =>
			arg->usage();
		}

	argv = arg->argv();

	# Start 9p infrastructure
	styx->init();
	styxservers->init(styx);
	styxservers->traceset(chatty);
	
	# Start FS navigator on /
	navch := chan of ref Navop;
	spawn navigator(navch);

	nav := Navigator.new(navch);
	(tc, srv) := Styxserver.new(fildes(0), nav, big Qroot);

	# Primary server loop
	loop:
	while((tmsg := <-tc) != nil) {
		# Switch on operations being performed on a given Fid
		pick msg := tmsg {
		Open =>
			srv.default(msg);

		Read =>
			fid := srv.getfid(msg.fid);

			if(fid.qtype & Sys->QTDIR) {
				# This is a directory read
				srv.default(msg);
				continue loop;
			}

			case int fid.path {
			Qlog =>
				# A read on our log file, tell them what they've already said ☺
				s := "";

				for(l := log; l != nil; l = tl l)
					s = hd l + s;

				srv.reply(styxservers->readstr(msg, s));

			* =>
				srv.default(msg);
			}

		Write =>
			fid := srv.getfid(msg.fid);

			case int fid.path {
			Qctl =>
				# Don't care about offset
				cmd := string msg.data;

				reply: ref Rmsg = ref Rmsg.Write(msg.tag, len msg.data);

				case cmd {
				* =>
					# Ignore empty writes
					if(cmd != nil)
						log = cmd :: log;
					else
						reply = ref Rmsg.Error(msg.tag, "empty write!");
				}
				srv.reply(reply);
				
			* =>
				srv.default(msg);
			}

		* =>
			srv.default(msg);
		}
	}

	exit;
}

# Navigator function for moving around under /
navigator(c: chan of ref Navop) {
	loop: 
	for(;;) {
		navop := <-c;
		pick op := navop {
		Stat =>
			op.reply <-= (dir(int op.path), nil);
			
		Walk =>
			if(op.name == "..") {
				op.reply <-= (dir(Qroot), nil);
				continue loop;
			}

			case int op.path&16rff {

			Qroot =>
				for(i := 1; i < Qmax; i++)
					if(tab[i].t1 == op.name) {
						op.reply <-= (dir(i), nil);
						continue loop;
					}

				op.reply <-= (nil, Enotfound);
			* =>
				op.reply <-= (nil, Enotdir);
			}
			
		Readdir =>
			for(i := 0; i < op.count && i + op.offset < (len tab) - 1; i++)
				op.reply <-= (dir(Qroot+1+i+op.offset), nil);

			op.reply <-= (nil, nil);
		}
	}
}

# Given a path inside the table, this returns a Sys->Dir representing that path.
dir(path: int): ref Sys->Dir {
	(nil, name, perm) := tab[path&16rff];

	d := ref sys->zerodir;

	d.name	= name;
	d.uid		= d.gid = user;
	d.qid.path	= big path;

	if(perm & Sys->DMDIR)
		d.qid.qtype = Sys->QTDIR;
	else
		d.qid.qtype = Sys->QTFILE;

	d.mtime = d.atime = 0;
	d.mode = perm;

	return d;
}
