</mkconfig

DISBIN = /dis

TARG=\
	simplefs.dis

</mkfiles/mkdis

demo:V: all
	dir = /n/s
	mount {simplefs} $dir
	echo 'Testing 1 2 3⋯' > $dir/ctl
	echo 'Is anyone out there?' > $dir/ctl
	echo 'Hello down there!' > $dir/ctl
	cat $dir/log
