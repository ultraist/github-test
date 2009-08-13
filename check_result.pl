use strict;
use warnings;
my $c = 0;
open("R", "results.txt") or die $!;
while (my $line = <R>) {
    my @rec = split(",", $line);
    if (scalar(@rec) != 10) {
	die "error: $c: $line";
    }
    ++$c;
}
close(R);
print "check ok\n";
