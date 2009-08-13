
sub read_user
{
    my $user = {};
    my $i = 0;

    open(U, "download/data.txt") or die $!;

    while (my $line = <U>) {
	chomp($line);
	my ($user_id, $repo_id) = split(":", $line);
	if (!exists($user->{$user_id})) {
	    $user->{$user_id} = {};
	    $user->{$user_id}->{$repo_id} = 1;
	} else {
	    $user->{$user_id}->{$repo_id} = 1;
	}
    }
    close(U);

    return $user;
}

my $user = read_user();

printf("%d\n", scalar(keys(%$user)));
foreach my $uid (keys(%$user)) {
    print join(" ", keys(%{$user->{$uid}})),"\n";
}
