#!/usr/bin/perl
# usage: perl bt_dl2.pl <tlv> <firstsz> <restsz> [maxsegs]
use strict; use warnings; use Fcntl; use POSIX ();
my ($fw,$nvm,$first,$rest,$mode)=@ARGV; $mode||="both"; alarm 900;
sysopen(my $fh,"/dev/ttyHS0",O_RDWR|O_NOCTTY) or die "open: $!";
my $t=POSIX::Termios->new; $t->getattr(fileno $fh) or die;
$t->setiflag(0); $t->setoflag(0); $t->setlflag(0);
$t->setcflag(POSIX::CS8()|POSIX::CREAD()|POSIX::CLOCAL()|0x80000000); $t->setispeed(4098); $t->setospeed(4098);
$t->setcc(POSIX::VMIN(),1); $t->setcc(POSIX::VTIME(),0);
$t->setattr(fileno $fh, POSIX::TCSANOW()) or die; POSIX::tcflush(fileno $fh, POSIX::TCIOFLUSH());
sub hx { join ' ', map {sprintf '%02x',ord} split //, $_[0] }
sub rd { my ($tmo)=@_; my $buf=''; my $rin=''; vec($rin,fileno($fh),1)=1;
  while (1) { my $n=select(my $r=$rin,undef,undef,$tmo); last unless $n; my $b; my $k=sysread($fh,$b,512); last unless $k; $buf.=$b; $tmo=0.05; } return $buf; }
sub cmd { my ($op,$data,$tmo)=@_; syswrite($fh,pack('CvC',1,$op,length $data).$data); return rd($tmo||1.0); }
print "version: ",hx(cmd(0xfc00,"\x19",1.5)),"\n";
for my $file ($fw,$nvm) {
  open(my $f,'<:raw',$file) or die; local $/; my $d=<$f>; close $f; my $len=length $d; my ($off,$seg)=(0,0);
  print "download $file ($len bytes)\n";
  while ($off<$len) { my $n=($seg==0)?$first:$rest; $n=$len-$off if $n>$len-$off;
    my $r=cmd(0xfc00,pack('CC',0x1e,$n).substr($d,$off,$n),1.0);
    print "seg $seg off $off resp: ",hx($r),"\n" if $seg<2 || $off+$n>=$len || $seg%300==0;
    if ($r eq '') { print "NO ACK at seg $seg off $off\n"; exit 1 }
    $off+=$n; $seg++; }
  print "done $file segs=$seg\n";
}
if ($mode eq "both" || $mode eq "edl") { print "patch reset: ",hx(cmd(0xfc00,"\x05",3.0)),"\n"; select(undef,undef,undef,1.0); }
if ($mode eq "both" || $mode eq "hci" || $mode eq "hciscan" || $mode eq "sleeptest" || $mode eq "keepalive" || $mode eq "noflow" || $mode eq "wake" || $mode eq "idle" || $mode eq "proxy") { for my $i (1..3) { my $r=cmd(0x0c03,"",3.0); print "hci reset try $i: ",hx($r),"\n"; last if $r ne ''; } }
print "version after: ",hx(cmd(0xfc00,"\x19",1.5)),"\n";

if ($mode eq "hciscan") {
  print "read local version: ",hx(cmd(0x1001,"",2.0)),"\n";
  print "LE scan params: ",hx(cmd(0x200b,pack('CvvCC',1,0x10,0x10,0,0),2.0)),"\n";
  print "LE scan enable: ",hx(cmd(0x200c,pack('CC',1,0),2.0)),"\n";
  my $buf=''; my $end=time+10; my %seen;
  while (time<$end) { $buf.=rd(1.0); }
  my $n=0; while ($buf =~ /\x04\x3e/g) { $n++ }
  print "LE meta events in 10s: $n, bytes ",length($buf),"\n";
  print "first bytes: ",hx(substr($buf,0,48)),"\n";
  print "LE scan disable: ",hx(cmd(0x200c,pack('CC',0,0),2.0)),"\n";
}

if ($mode eq "sleeptest") {
  for my $w (1..5) { my $b=rd(4.0); print "idle ",$w*4,"s spontaneous: [",hx($b),"]\n"; }
  my $r=cmd(0x1001,"",2.0); print "read local version after idle: [",hx($r),"]\n";
  if ($r eq '') { syswrite($fh,"\xfd"); my $a=rd(1.5); print "wake 0xFD -> [",hx($a),"]\n"; $r=cmd(0x1001,"",2.0); print "version after wake: [",hx($r),"]\n"; }
}

if ($mode eq "keepalive") {
  my ($ok,$bad)=(0,0);
  for my $i (1..30) { my $r=cmd(0x1001,"",1.5); if ($r ne '') { $ok++ } else { $bad++; print "no answer at t=",$i*3,"s\n"; } select(undef,undef,undef,1.5); }
  print "keepalive over 90s: ok=$ok bad=$bad\n";
}

if ($mode eq "noflow") {
  select(undef,undef,undef,12);
  my $t2=POSIX::Termios->new; $t2->getattr(fileno $fh);
  $t2->setcflag(POSIX::CS8()|POSIX::CREAD()|POSIX::CLOCAL()); $t2->setattr(fileno $fh, POSIX::TCSANOW());
  print "flow control OFF after 12s idle\n";
  my $r=cmd(0x1001,"",2.0); print "version (no wake): [",hx($r),"]\n";
  syswrite($fh,"\xfd"); my $a=rd(1.5); print "wake 0xFD -> [",hx($a),"]\n";
  $r=cmd(0x1001,"",2.0); print "version after wake: [",hx($r),"]\n";
}

sub setup2 { my ($speed,$flow)=@_; my $tt=POSIX::Termios->new; $tt->getattr(fileno $fh) or die;
  $tt->setiflag(0); $tt->setoflag(0); $tt->setlflag(0);
  $tt->setcflag(POSIX::CS8()|POSIX::CREAD()|POSIX::CLOCAL()|($flow?0x80000000:0)); $tt->setispeed($speed); $tt->setospeed($speed);
  $tt->setcc(POSIX::VMIN(),1); $tt->setcc(POSIX::VTIME(),0); $tt->setattr(fileno $fh, POSIX::TCSANOW()) or die; }
if ($mode eq "wake") {
  if ($ENV{CHIPVER}) { open(my $bp,"+<","/dev/btpower") or die "btpower: $!"; my $rc=ioctl($bp,0xbfae,hex($ENV{CHIPVER})); print "BT_CMD_CHIPSET_VERS(0x$ENV{CHIPVER}) rc=",(defined $rc?$rc:"err $!"),"\n"; select(undef,undef,undef,0.5); { my $q=cmd(0x1001,"",2.0); print "version right after the ioctl: [",hx($q),"]\n"; } }
  my $idle=$ENV{IDLE}||12; print "idle ${idle}s so the chip can fall asleep...\n"; select(undef,undef,undef,$idle);
  my $r=cmd(0x1001,"",2.0); print "version after idle (no wake): [",hx($r),"]\n";
  # Android HAL: flow off -> 38400 -> send 0x00 -> back to max -> flow on
  setup2(15,0); syswrite($fh,"\x00"); select(undef,undef,undef,0.05); setup2(4098,1); select(undef,undef,undef,0.15);
  my $a=rd(0.5); print "after 0x00 wake pulse, spontaneous: [",hx($a),"]\n";
  syswrite($fh,"\xfd"); my $w=rd(1.0); print "0xFD (WAKE_IND) -> [",hx($w),"]\n";
  $r=cmd(0x1001,"",2.0); print "version after wake: [",hx($r),"]\n";
  for my $i (1..3) { select(undef,undef,undef,4); $r=cmd(0x1001,"",2.0); print "still alive after +",$i*4,"s: [",hx($r),"]\n"; }
}

if ($mode eq "idle") {
  for my $w (15,10,15,20,30) {
    select(undef,undef,undef,$w); my $t0=time;
    my $r=cmd(0x1001,"",1.5); print "after +${w}s idle: version [",hx($r),"]\n";
    if ($r eq '') { for my $i (1..3) { syswrite($fh,"\xfd"); my $a=rd(0.8); print "   WAKE_IND try $i -> [",hx($a),"]\n"; last if $a ne ''; }
                    $r=cmd(0x1001,"",1.5); print "   version after wake attempt [",hx($r),"]\n"; }
  }
}

if ($mode eq "proxy") {
  # Keep ttyHS0 open for good and expose it as a pty for btattach/bluez, so the UART is never shut down (RTS stays asserted).
  alarm 0;
  open(my $m,"+<","/dev/ptmx") or die "ptmx: $!";
  my $lk=pack("i",0); ioctl($m,0x40045431,$lk) or die "TIOCSPTLCK: $!";            # unlock slave
  my $n=pack("i",0); ioctl($m,0x80045430,$n) or die "TIOCGPTN: $!"; my $num=unpack("i",$n);
  my $slave="/dev/pts/$num"; chmod 0666,$slave;
  if (open(my $pf,">","/tmp/bt_pty")) { print $pf "$slave\n"; close $pf }
  print "proxy: slave=$slave\n"; $|=1;
  my $mfd=fileno($m); my $ffd=fileno($fh);
  my ($b2c,$c2b)=(0,0);
  while (1) {
    my $rin=''; vec($rin,$mfd,1)=1; vec($rin,$ffd,1)=1;
    my $nf=select(my $rout=$rin,undef,undef,30);
    next unless $nf;
    if (vec($rout,$ffd,1)) { my $b; my $k=sysread($fh,$b,4096); die "chip read: $!" unless defined $k; if ($k) { syswrite($m,$b); $c2b+=$k } }
    if (vec($rout,$mfd,1)) { my $b; my $k=sysread($m,$b,4096); if (defined $k && $k) { my $o2=0; while ($o2<$k) { my $w=syswrite($fh,$b,$k-$o2,$o2); last unless defined $w; $o2+=$w } $b2c+=$k } }
  }
}
