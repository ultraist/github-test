# testtest
use strict;
use warnings;
$| = 1;

sub read_repo
{
  my %repo;
  my @conv;
  my $i = 0;

  print "read repos\r";
  
  open(R, "download/repos.txt") or die $!;
  
  while (my $line = <R>) {
    chomp($line);
    my ($repo_id, undef) = split(":", $line);
    $repo{$repo_id} = $i;
    $conv[$i] = $repo_id;
    ++$i;
  }
  close(R);
  printf("read repo %d\n", $i);
  
  return { id => \%repo, conv => \@conv, n => $i };
}

sub read_user
{
  my $repo = shift;
  my %user;
  my $i = 0;
  
  print "read users\r";
  
  open(U, "download/data.txt") or die $!;
  
  while (my $line = <U>) {
    chomp($line);
    my ($user_id, $repo_id) = split(":", $line);
    if (!exists($user{$user_id})) {
      $user{$user_id} = {};
      my $repo_i = $repo->{id}->{$repo_id};
      if (defined($repo_i)) {
        $user{$user_id}->{$repo_i} = 1;
      }
    } else {
      my $repo_i = $repo->{id}->{$repo_id};
      if (defined($repo_i)) {
        $user{$user_id}->{$repo_i} = 1;
      }
    }
  }
  close(U);
  
  my %sample_user;
  my $count = scalar(keys(%user));
  my $avg = 0.0;
  my $var = 0.0;
  my $sd = 0.0;
  my $samples = 0;
  foreach my $k (keys(%user)) {
    my $p = scalar(keys(%{$user{$k}}));
    $avg += $p / $count;
  }
  foreach my $k (keys(%user)) {
    my $p = scalar(keys(%{$user{$k}}));
    $var += ($p - $avg) ** 2 / ($count - 1);
  }
  $sd = sqrt($var);
  foreach my $k (keys(%user)) {
    my $p = scalar(keys(%{$user{$k}}));
    if ($avg / 2 < $p && $p < $avg + $sd) {
      $sample_user{$k} = $user{$k};
    }
  }
  $samples =  scalar(keys(%sample_user));
  printf("read user , count: %d, var:%f, sd:%f, samples:%d\n", $count, $var, $sd, $samples);
  
  return { id => \%sample_user, all_id => \%user, n => $samples};
}


sub read_test
{
  my @uid;
  open(T, "download/test.txt") or die $!;
  
  print "read test\r";
  
  while (my $line = <T>) {
    chomp($line);
    my $user_id = $line;
    push(@uid, $user_id);
  }
  close(T);
  return \@uid;
}

sub jaccard
{
  my ($v1, $v2) = @_;
  my $ng = 0.1;
  my $ok11 = 0.1;
  
  foreach my $k (keys(%$v1)) {
    if (defined($v2->{$k})) {
      $ok11 += 1.0;
    } else {
      $ng += 1.0;
    }
  }
  foreach my $k (keys(%$v2)) {
    if (!defined($v1->{$k})) {
      $ng += 1.0;
    }
  }
  
  return ($ok11 + $ng) / $ok11;
}

sub print_vec
{
  my ($vec, $repo) = @_;

  foreach my $k (keys(%$vec)) {
    print "\t$repo->{conv}->[$k]";
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
  my ($i, $j, $c);
  
  foreach my $uid (keys(%{$user->{id}})) {
    my $user_vec = $user->{id}->{$uid};
    push(@dist, { uid => $uid, dist => jaccard($vec, $user_vec)})
  }
  @dist = sort { $a->{dist} <=> $b->{dist} } @dist;
  #print "------------------\n";
  #print_vec($vec, $repo);
  
  for ($j = 0; $j < $n; ++$j) {
    my $repo_vec = $user->{id}->{$dist[$j]->{uid}};
    my $weight = 1.0;
    #if ($j < 5) {
    #  print "$j:";
    #  print_vec($repo_vec, $repo);
    #}
    foreach $i (keys(%$repo_vec)) {
      if (defined($score_vec{$i})) {
        $score_vec{$i}->{score} += $weight;
      } else {
        $score_vec{$i} = { i => $i, score => 0.0 };
        $score_vec{$i}->{score} = $weight;
      }
    }
  }
  @rec_vec = sort { $b->{score} <=> $a->{score} } values(%score_vec);
  $i = $c = 0;
  while ($c < 10) {
    if (!defined($vec->{$rec_vec[$i]->{i}})) {
      #printf("%s:%f\n", $repo->{conv}->[$rec_vec[$i]->{i}], $rec_vec[$i]->{count});
      push(@result, $repo->{conv}->[$rec_vec[$i]->{i}]);
      ++$c;
    }
    if (++$i >= scalar(@rec_vec)) {
      while ($c < 10) {
        print "oh..shit!\n";
        push(@result, $repo->{conv}->[int(rand($repo->{n}-1))]);
        ++$c;
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
