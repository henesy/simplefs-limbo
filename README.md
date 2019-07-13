# Simple FS

## Requirements

This filesystem is written in the Limbo programming language for the Inferno operating system. 

The [purgatorio](https://code.9front.org/hg/purgatorio)  fork of Inferno is recommended. 

No other dependencies are required if Inferno is installed. 

## Building

	mk

## Demo

	mk demo

## Usage

### Arguments

	usage: simplefs [-D]

`-D` enables debug logging and tracing via styx(2).  

'-u' specifies to run the server as owned by `user`. 

### Command format

Commands are written to the `/ctl` file in the fs. 

### Filesystem structure

`/ctl`		-- command input file

`/log``	-- log of commands written thus far

## Examples

If you're used to how Plan 9 provides file servers as per postmountsrv(2) and friends, the operation of Inferno file servers may be unintuitive. 

In Inferno, a styx(2) file server listens on stdin and if run from the shell directly, will seem to just hang. There are several approaches to making the server accessible, in this case, we use mount(1) to place our file server in an intuitive location. 

From inside Inferno:

	; mount {mntgen} /n	# Not necessary under purgatorio
	; mount {simplefs} /n/s
	; ls -sl /n/s
	---w--w--w- M 23 none none 0 Dec 31  1969 /n/s/ctl
	--r--r--r-- M 23 none none 0 Dec 31  1969 /n/s/log
	; echo hi > /n/s/ctl
	; cat /n/s/log
	hi
	; echo ducks > /n/s/ctl
	; cat /n/s/log
	hi
	ducks
	; echo -n > /n/s/ctl
	echo: write error: empty write!
	; 
