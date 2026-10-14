use strict; use warnings; use Fcntl; use POSIX (); alarm 30;
sysopen(my $fh,"/dev/ttyHS0",O_RDWR|O_NOCTTY) or die "open: $!";
my $t=POSIX::Termios->new; $t->getattr(fileno $fh) or die;
$t->setiflag(0); $t->setoflag(0); $t->setlflag(0);
$t->setcflag(POSIX::CS8()|POSIX::CREAD()|POSIX::CLOCAL()|0x80000000); $t->setispeed(4098); $t->setospeed(4098);
$t->setcc(POSIX::VMIN(),1); $t->setcc(POSIX::VTIME(),0); $t->setattr(fileno $fh, POSIX::TCSANOW()) or die; POSIX::tcflush(fileno $fh, POSIX::TCIOFLUSH());
sub hx { join ' ', map {sprintf '%02x',ord} split //, $_[0] }
sub rd { my ($tmo)=@_; my $buf=''; my $rin=''; vec($rin,fileno($fh),1)=1;
  while (1) { my $n=select(my $r=$rin,undef,undef,$tmo); last unless $n; my $b; my $k=sysread($fh,$b,512); last unless $k; $buf.=$b; $tmo=0.1; } return $buf; }
syswrite($fh,"\x01\x01\x10\x00"); print "read local version: [",hx(rd(1.5)),"]\n";
syswrite($fh,"\x01\x03\x0c\x00"); print "hci reset: [",hx(rd(1.5)),"]\n";
