use strict; use warnings; use Fcntl; use POSIX (); alarm 120;
sysopen(my $fh,"/dev/ttyHS0",O_RDWR|O_NOCTTY) or die "open: $!";
sub setup { my ($speed,$flow)=@_; my $t=POSIX::Termios->new; $t->getattr(fileno $fh) or die;
  $t->setiflag(0); $t->setoflag(0); $t->setlflag(0);
  $t->setcflag(POSIX::CS8()|POSIX::CREAD()|POSIX::CLOCAL()|($flow?0x80000000:0)); $t->setispeed($speed); $t->setospeed($speed);
  $t->setcc(POSIX::VMIN(),1); $t->setcc(POSIX::VTIME(),0); $t->setattr(fileno $fh, POSIX::TCSANOW()) or die; POSIX::tcflush(fileno $fh, POSIX::TCIOFLUSH()); }
sub hx { join ' ', map {sprintf '%02x',ord} split //, $_[0] }
sub rd { my ($tmo)=@_; my $buf=''; my $rin=''; vec($rin,fileno($fh),1)=1;
  while (1) { my $n=select(my $r=$rin,undef,undef,$tmo); last unless $n; my $b; my $k=sysread($fh,$b,512); last unless $k; $buf.=$b; $tmo=0.1; } return $buf; }
my @sp=([4098,115200],[4099,230400],[4100,460800],[4103,921600],[4104,1000000],[4107,2000000],[4109,3000000],[4111,4000000]);
# wake pulse exactly like the Android HAL: flow off, 38400, 0x00, then the working speed with flow on
for my $s (@sp) { for my $flow (1,0) {
  setup(15,0); syswrite($fh,"\x00"); select(undef,undef,undef,0.05);
  setup($s->[0],$flow); my $pre=rd(0.25);
  syswrite($fh,"\xfd"); my $w=rd(0.4);
  syswrite($fh,"\x01\x03\x0c\x00"); my $r=rd(0.6);
  printf "%-8d flow=%d  after-pulse=[%s] wake->[%s] hci_reset->[%s]\n",$s->[1],$flow,hx($pre),hx($w),hx($r);
} }
