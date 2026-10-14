#!/usr/bin/perl
# Minimal stand-in for Android's logd write socket: collects liblog datagrams from the chroot into /tmp/android.log
use strict; use Socket;
my $path="/dev/socket/logdw"; unlink $path; mkdir "/dev/socket";
socket(my $s, AF_UNIX, SOCK_DGRAM, 0) or die "socket: $!";
bind($s, sockaddr_un($path)) or die "bind: $!"; chmod 0666, $path;
open(my $out, ">>", "/tmp/android.log") or die; select((select($out), $|=1)[0]);
my @pr=qw(? ? V D I W E F S);
while (1) {
  my $buf=''; defined(recv($s,$buf,8192,0)) or next;
  next if length($buf) < 12;
  my ($id,$tid,$sec,$nsec)=unpack("C v V V",substr($buf,0,11)); my $rest=substr($buf,11);
  next if length($rest) < 2;
  my $p=ord(substr($rest,0,1)); my ($tag,$msg)=split(/\0/,substr($rest,1),3);
  $msg//=''; $msg=~s/\n+$//;
  printf $out "%s/%s(%d): %s\n", $pr[$p]//$p, $tag//'', $tid, $msg;
}
