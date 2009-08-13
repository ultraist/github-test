# testtest
use strict;
use warnings;
use List::MoreUtils qw/uniq/;
$| = 1;

sub read_repo
{
  my $repo = {};
  my $author = {};
  my @conv;
  my $i = 0;

  print "read repos\r";
  
  open(R, "download/repos.txt") or die $!;
  
  while (my $line = <R>) {
    chomp($line);
    my ($repo_id, $footer) = split(":", $line);
    my ($name, $date, $base) = split(",", $footer);
    my ($author_name, $repo_name) = split("/", $name);

    $repo->{$repo_id} = { rate => 0.0, base => $base, author => $author_name };

    if (!defined($author->{$author_name})) {
	$author->{$author_name} = [];
	push(@{$author->{$author_name}}, $repo_id);
    } else {
	push(@{$author->{$author_name}}, $repo_id);
    }
    
    ++$i;
  }
  close(R);

  foreach my $id (keys(%$repo)) {
      my $base_id = $repo->{$id}->{base};
      if ($base_id) {
	  if (!defined($repo->{$id}->{fork})) {
	      $repo->{$id}->{fork} = [];
	      push(@{$repo->{$id}->{fork}}, $base_id);
	  } else {
	      push(@{$repo->{$id}->{fork}}, $base_id);
	  }
      }
  }
  
  printf("read repo %d\n", $i);
  
  return { id => $repo, author => $author, n => $i };
}

sub read_user
{
  my ($repo, $lang) = @_;
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


  # lang
  my $user_lang = {};
  foreach my $uid (keys(%$user)) {
      my @skill_lang;
      foreach my $rid (keys(%{$user->{$uid}})) {
	  if (defined($lang->{$rid})) {
	      push(@skill_lang, @{$lang->{$rid}});
	  }
      }
      $user_lang->{$uid} = [];
      push(@{$user_lang->{$uid}}, uniq(@skill_lang));
  }
  
  return { id => $sample_user, all_id => $user, lang => $user_lang, n => $samples};
#  return { id => $user, all_id => $user, n => $count};
}

sub get_relational_repo
{
    my ($repo, $id) = @_;
    my $vec = {$id => 0.0};
    my @fork = get_fork($repo, $vec);
    my @fork_base = get_fork_base($repo, $vec);
    my @rel_repo;

    push(@rel_repo, @fork);
    push(@rel_repo, @fork_base);
    
    return uniq(@rel_repo);
}

sub read_lang
{
    my $repo = shift;
    my $lang = {};
    open(L, "download/lang.txt") or die $!;

    while (my $line = <L>) {
	my @repo_lang;
	chomp($line);
	my($repo_id, $lang_info) = split(":", $line);
	my @lang_line = split(",", $lang_info);
	for (my $i = 0; $i < @lang_line; $i++) {
	    push(@repo_lang, (split(";", $lang_line[$i]))[0]);
	}
	if (!defined($lang->{$repo_id})) {
	    $lang->{$repo_id} = [];
	}
	push(@{$lang->{$repo_id}}, @repo_lang);
    }
    close(L);

    for (my $i = 0; $i < 3; ++$i) {
	foreach my $id (keys(%{$repo->{id}})) {
	    my @rel_repo = get_relational_repo($repo, $id);
	    my @repo_lang;
	    
	    foreach my $rid (@rel_repo) {
		if (defined($lang->{$rid})) {
		    push(@repo_lang, @{$lang->{$rid}});
		}
	    }
	    push(@{$lang->{$id}}, @repo_lang);
	}
    }

    foreach my $id (keys(%$lang)) {
	@{$lang->{$id}} = uniq(@{$lang->{$id}});
    }

    return $lang;
}

sub match_lang
{
    my ($user_lang, $repo_lang) = @_;

    if (!$user_lang || !@$user_lang) {
	return 1;
    }
    if (!$repo_lang || !@$repo_lang) {
	return undef;
    }

    foreach my $i (@$repo_lang) {
	foreach my $j (@$user_lang) {
	    if ($i eq $j) {
		return 1;
	    }
	}
    }
    return undef;
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
	    $repo->{id}->{$i}->{rate} += 1.0;
	}
    }
    foreach my $i (keys(%{$repo->{id}})) {
	if ($max_count < $repo->{id}->{$i}->{rate}) {
	    $max_count = $repo->{id}->{$i}->{rate};
	}
    }
    my $factor = 1.0 / $max_count;
    foreach my $i (keys(%{$repo->{id}})) {
	$repo->{id}->{$i}->{rate} *= $factor;
    }

    my $rank = [];
    foreach my $i (keys(%{$repo->{id}})) {
	push(@$rank, { id => $i, score => $repo->{id}->{$i}->{rate}});
    }
    @$rank = sort { $b->{score} <=> $a->{score} } @$rank;
    $repo->{rank} = $rank;
}

sub sim
{
  my ($v1, $v2) = @_;
  my ($n1, $n2) = (scalar(keys(%$v1)), scalar(keys(%$v2)));
  my $ok11 = 0;
  my $n = 0;
  
  foreach my $k (keys(%$v1)) {
    if (defined($v2->{$k})) {
      $ok11 += 1.0;
    }
    ++$n;
  }

  if ($n == 0) {
      return 0;
  }

  
  return $ok11 / ($n1 > $n2 ? $n1:$n2);
}

sub print_vec
{
  my ($vec, $repo) = @_;

  foreach my $k (keys(%$vec)) {
    print "\t$k";
  }
  print ";;\n";
}

sub _get_fork
{
    my ($repo, $id, $fork) = @_;
    my $n = 0;
    
    if (defined($repo->{id}->{$id}->{fork})) {
	foreach my $i (@{$repo->{id}->{$id}->{fork}}) {
	    push(@$fork, { id => $i, rate => $repo->{id}->{$i}->{rate}});

	    if (++$n >= 2) {
		last;
	    }
	}
    }
}

sub get_fork
{
    my ($repo, $vec) = @_;
    my $fork = [];
    my $fork_tmp = [];

    foreach my $id (keys(%$vec)) {
	_get_fork($repo, $id, $fork_tmp);
    }
    foreach my $id (@$fork_tmp) {
	if (!defined($vec->{$id->{id}})) {
	    push(@$fork, $id);
	}
    }
    @$fork_tmp = sort { $b->{rate} <=> $a->{rate} } @$fork;
    @$fork = ();
    foreach my $id (@$fork_tmp) {
	push(@$fork, $id->{id});
    }

    return uniq(@$fork);
}


sub _get_fork_base
{
    my ($repo, $id, $fork_base, $n) = @_;

    if ($repo->{id}->{$id}->{base}) {
	my $base_id = $repo->{id}->{$id}->{base};
	push(@$fork_base, { id => $base_id, rate => $repo->{id}->{$base_id}->{rate}});
	_get_fork_base($repo, $base_id, $fork_base, $n + 1);
    }
}

sub get_fork_base
{
    my ($repo, $vec) = @_;
    my $fork_base_tmp = [];
    my $fork_base = [];
    
    foreach my $id (keys(%$vec)) {
	_get_fork_base($repo, $id, $fork_base_tmp, 0);
    }
    foreach my $id (@$fork_base_tmp) {
	if (!defined($vec->{$id->{id}})) {
	    push(@$fork_base, $id);
	}
    }
    @$fork_base_tmp = sort { $b->{rate} <=> $a->{rate} } @$fork_base;
    @$fork_base = ();
    foreach my $id (@$fork_base_tmp) {
	push(@$fork_base, $id->{id});
    }

    return uniq(@$fork_base);
}

sub _get_author_repo
{
    my ($repo, $id, $author_repo) = @_;
    my $n = 0;
    
    foreach my $id (@{$repo->{author}->{$repo->{id}->{$id}->{author}}}) {
	push(@$author_repo, { rate => $repo->{id}->{$id}->{rate}, id => $id });

	if (++$n >= 2 ) {
	    last;
	}
    }
}

sub get_author_repo
{
    my ($repo, $vec) = @_;
    my $author_repo_tmp = [];
    my $author_repo = [];

    foreach my $id (keys(%$vec)) {
	_get_author_repo($repo, $id, $author_repo_tmp);
    }
    
    foreach my $id (@$author_repo_tmp) {
	if (!defined($vec->{$id->{id}})) {
	    push(@$author_repo, $id);
	}
    }
    @$author_repo_tmp = sort { $b->{rate} <=> $a->{rate} } @$author_repo;
    @$author_repo = ();
    foreach my $id (@$author_repo_tmp) {
	push(@$author_repo, $id->{id});
    }

    return uniq(@$author_repo);
}

sub recommend_repo
{
  my ($user, $repo, $lang, $user_id, $n) = @_;
  my %score_vec;
  my @rec_vec;
  my @dist;
  my @result;
  my ($i, $j, $nn);
  my $nfac = 1.0 / $n;
  my $vec = $user->{all_id}->{$user_id};

  foreach my $uid (keys(%{$user->{id}})) {
    my $user_vec = $user->{id}->{$uid};
    push(@dist, { uid => $uid, dist => -sim($vec, $user_vec)})
  }
  @dist = sort { $a->{dist} <=> $b->{dist} } @dist;
  #print "------------------\n";
  #print_vec($vec, $repo);

  $nn = 0;
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
		$score_vec{$i}->{score} = $weight + $nfac * $repo->{id}->{$i}->{rate};
	    } else {
		$score_vec{$i}->{score} += $weight + $nfac * $repo->{id}->{$i}->{rate};
	    }
	}
	++$nn;
    }
  }
  
  my @fork_base = get_fork_base($repo, $vec);
  #if (@fork_base) {
  #    printf("fork base: %d, %s\n", scalar(@fork_base), join(",", @fork_base));
  #} else {
  #    printf("fork base: 0\n");
  #}

  foreach $i (@fork_base) {
      push(@result, $i);
      
      if (@result >= 10) {
	  last;
      }
  }


  if (@result < 10) {
      my @author_repo = get_author_repo($repo, $vec);
#      printf("author_repo: %d, %s\n", scalar(@author_repo), join(",", @author_repo));
      
      foreach $i (@author_repo) {
	  push(@result, $i);
	  
	  if (@result >= 10) {
	      last;
	  }
      }
  }
  
  if (@result < 10) {
      if ($nn == 0) {
	  for ($j = 0; $j < scalar(@{$repo->{rank}}); ++$j) {
	      if (!defined($vec->{$repo->{rank}->[$j]->{id}})
		  && match_lang($user->{lang}->{$user_id}, $lang->{$repo->{rank}->[$j]->{id}}))
	      {
		  push(@result, $repo->{rank}->[$j]->{id});
		  if (@result >= 10) {
		      last;
		  }
	      }
	  }
      } else {
	  @rec_vec = sort { $b->{score} <=> $a->{score} } values(%score_vec);
	  $i = 0;
	  while (@result < 10) {
	      if (!defined($vec->{$rec_vec[$i]->{i}})) {
		  #printf("%s:%f\n", $rec_vec[$i]->{i}, $rec_vec[$i]->{score});
		  push(@result, $rec_vec[$i]->{i});
		  if (@result >= 10) {
		      last;
		  }
	      }
	      ++$i;
	      if (!defined($rec_vec[$i]->{i})) {
		  for ($j = 0; $j < scalar(@{$repo->{rank}}); ++$j) {
		      if (!defined($vec->{$repo->{rank}->[$j]->{id}})
			  && match_lang($user->{lang}->{$user_id}, $lang->{$repo->{rank}->[$j]->{id}}))
		      {
			  push(@result, $repo->{rank}->[$j]->{id});
			  if (@result >= 10) {
			      last;
			  }
		      }
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
  my $lang = read_lang($repo);
  my $user = read_user($repo, $lang);
  my $test = read_test();
  my $count = 0;

  repo_rank($repo, $user);
  
  open(O, ">results.txt") or die $!;
  select(O);$|=1;select(STDOUT);
  
  foreach my $uid (@$test) {
      printf("recommend %.02f%%..\r", 100 * $count / scalar(@$test));
    
      my @result = recommend_repo($user, $repo, $lang, $uid, 100);
      print O $uid, ":", join(",", @result), "\n";
      #print $uid, ":", join(",", @result), "\n";
      ++$count;
  }
  close(O);
}
