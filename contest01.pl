# testtest
use strict;
use warnings;
$| = 1;

sub read_repo
{
  my $repo = {};
  my @conv;
  my $i = 0;

  print "read repos\r";
  
  open(R, "download/repos.txt") or die $!;
  
  while (my $line = <R>) {
    chomp($line);
    my ($repo_id, undef) = split(":", $line);
    $repo->{$repo_id} = 0.0;
    ++$i;
  }
  close(R);
  printf("read repo %d\n", $i);
  
  return { id => $repo, n => $i };
}

sub read_user
{
  my $repo = shift;
  my $user = {};
  my $i = 0;
  
  print "read users\r";
  
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
  
  my $sample_user = {};
  my $count = scalar(keys(%$user));
  my $avg = 0.0;
  my $var = 0.0;
  my $sd = 0.0;
  my $samples = 0;
  foreach my $k (keys(%$user)) {
    my $p = scalar(keys(%{$user->{$k}}));
    $avg += $p / $count;
  }
  foreach my $k (keys(%$user)) {
    my $p = scalar(keys(%{$user->{$k}}));
    $var += ($p - $avg) ** 2 / ($count - 1);
  }
  $sd = sqrt($var);
  foreach my $k (keys(%$user)) {
    my $p = scalar(keys(%{$user->{$k}}));
    if ($avg / 2 < $p && $p < $avg + $sd) {
      $sample_user->{$k} = $user->{$k};
    }
  }
  $samples =  scalar(keys(%$sample_user));
  printf("read user , count: %d, var:%f, sd:%f, samples:%d\n", $count, $var, $sd, $samples);
  
  return { id => $sample_user, all_id => $user, n => $samples};
#  return { id => $user, all_id => $user, n => $count};
}

sub read_test
{
  my $uid = [];
  open(T, "download/test.txt") or die $!;
  
  print "read test\r";
  
  while (my $line = <T>) {
    chomp($line);
    my $user_id = $line;
    push(@$uid, $user_id);
  }
  close(T);
  return $uid;
}

sub repo_rank
{
    my ($repo, $user) = @_;
    my $max_count  = 0;

    foreach my $uid (keys(%{$user->{all_id}})) {
	my $repo_vec = $user->{all_id}->{$uid};
	foreach my $i (keys(%$repo_vec)) {
	    $repo->{id}->{$i} += 1.0;
	}
    }
    foreach my $i (keys(%{$repo->{id}})) {
	if ($max_count < $repo->{id}->{$i}) {
	    $max_count = $repo->{id}->{$i};
	}
    }
    my $factor = 1.0 / $max_count;
    foreach my $i (keys(%{$repo->{id}})) {
	$repo->{id}->{$i} *= $factor;
    }

    my $rank = [];
    foreach my $i (keys(%{$repo->{id}})) {
	push(@$rank, { id => $i, score => $repo->{id}->{$i}});
    }
    @$rank = sort { $b->{score} <=> $a->{score} } @$rank;
    $repo->{rank} = $rank;
}

sub sim
{
  my ($v1, $v2) = @_;
  my $n = 0;
  my $ok11 = 0;
  
  foreach my $k (keys(%$v1)) {
    if (defined($v2->{$k})) {
      $ok11 += 1.0;
    }
    ++$n;
  }
  if ($n == 0) {
      return 0;
  }
  
  return $ok11 / $n;
}

sub print_vec
{
  my ($vec, $repo) = @_;

  foreach my $k (keys(%$vec)) {
    print "\t$k";
  }
  print ";;\n";
}

sub recommend_repo
{
  my ($user, $repo, $vec, $n) = @_;
  my %score_vec;
  my @rec_vec;
  my @dist;
  my @result;
  my ($i, $j, $c, $matchs);
  my $nfac = 1.0 / $n;
  
  foreach my $uid (keys(%{$user->{id}})) {
    my $user_vec = $user->{id}->{$uid};
    push(@dist, { uid => $uid, dist => -sim($vec, $user_vec)})
  }
  @dist = sort { $a->{dist} <=> $b->{dist} } @dist;
  #print "------------------\n";
  #print_vec($vec, $repo);

  $matchs = 0;
  for ($j = 0; $j < $n; ++$j) {
    my $repo_vec = $user->{id}->{$dist[$j]->{uid}};
    my $weight = 1.0 - $j / $n;
    if ($dist[$j]->{dist} != 0.0) {
	#if ($j < 5) {
	#  print "$j($dist[$j]->{dist}):";
	#  print_vec($repo_vec, $repo);
	#}
	foreach $i (keys(%$repo_vec)) {
	    if (!defined($score_vec{$i})) {
		$score_vec{$i} = { i => $i, score => 0.0 };
		$score_vec{$i}->{score} = $weight + $nfac * $repo->{id}->{$i};
	    } else {
		$score_vec{$i}->{score} += $weight + $nfac * $repo->{id}->{$i};
	    }
	}
	++$matchs;
    }
  }
  
  if ($matchs == 0) {
      $c = 0;
      for ($j = 0; $j < scalar(@{$repo->{rank}}); ++$j) {
	  if (!defined($vec->{$repo->{rank}->[$j]->{id}})) {
	      push(@result, $repo->{rank}->[$j]->{id});
	      ++$c;
	  }
	  if ($c >= 10) {
	      last;
	  }
      }
  } else {
      @rec_vec = sort { $b->{score} <=> $a->{score} } values(%score_vec);
      $i = $c = 0;
      while ($c < 10) {
	  if (!defined($vec->{$rec_vec[$i]->{i}})) {
	      #printf("%s:%f\n", $rec_vec[$i]->{i}, $rec_vec[$i]->{score});
	      push(@result, $rec_vec[$i]->{i});
	      ++$c;
	  }
	  ++$i;
	  if (!defined($rec_vec[$i]->{i})) {
	      for ($j = 0; $j < scalar(@{$repo->{rank}}); ++$j) {
		  if (!defined($vec->{$repo->{rank}->[$j]->{id}})) {
		      push(@result, $repo->{rank}->[$j]->{id});
		      ++$c;
		  }
		  if ($c >= 10) {
		      last;
		  }
	      }
	  }
      }
  }
  return @result;
}

super_testttt:
{
  my $repo = read_repo();
  my $user = read_user($repo);
  my $test = read_test();
  my $count = 0;

  repo_rank($repo, $user);
  
  open(O, ">results.txt") or die $!;
  select(O);$|=1;select(STDOUT);
  
  foreach my $uid (@$test) {
    printf("recommend %.02f%%..\r", 100 * $count / scalar(@$test));
    
    my $test_vec = $user->{all_id}->{$uid};
    my @result = recommend_repo($user, $repo, $test_vec, 100);
    print O $uid, ":", join(",", @result), "\n";
    #print $uid, ":", join(",", @result), "\n";
    ++$count;
  }
  close(O);
}
