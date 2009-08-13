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
  my ($repo, $lang, $topic) = @_;
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

  # topic
  $i = 0;
  my $user_topic = {};
  if (!-f "topic_vec.txt") {
      open(T, ">topic_vec.txt") or die $!;
      foreach my $uid (keys(%$sample_user)) {
	  print "topic vec $i..\r";++$i;
	  $user_topic->{$uid} = topic_vector($topic, $user->{$uid});
	  print T sprintf("%s:%s\n", $uid, join(",", @{$user_topic->{$uid}}));
      }
      close(T);
  } else {
      open(T, "topic_vec.txt") or die $!;
      while (my $line = <T>) {
	  chomp($line);
	  my($uid, $v) = split(":", $line);
	  my @vec = split(",", $v);
	  $user_topic->{$uid} = [];
	  @{$user_topic->{$uid}} = @vec;
      }
      close(T);
  }

  printf("read user , count: %d, var:%f, sd:%f, samples:%d\n", $count, $var, $sd, $samples);


  return { id => $sample_user, all_id => $user, topic => $user_topic, lang => $user_lang, n => $samples};
#  return { id => $user, all_id => $user, n => $count};
}

sub read_topic
{
    my $topic = [];
    my $n = 0;
    my %current_words;

    print "read topic\r";
    
    open(T, "lda/model-01000.twords") or die $!;
    my $line = <T>; # first topic
    
    while ($line = <T>) {
	chomp($line);
	if ($line =~ /^\s/) {
	    $line =~ s/^\s//g;
	    $line =~ s/\s+/ /g;
	    my($word, $likely) = split(/ /, $line);
	    $current_words{$word} = $likely;
	} else {
	    $topic->[$n] = {};
	    %{$topic->[$n]} = %current_words;
	    %current_words = ();
	    ++$n;
	}
    }
    $topic->[$n] = {};
    %{$topic->[$n]} = %current_words;

    print "read topic $n\n";

    return $topic;
}

sub topic_vector
{
    my ($topic, $user_vec) = @_;
    my $m = scalar(@$topic);
    my $i;
    my $topic_vec = [];
    
    for ($i = 0; $i < $m; ++$i) {
	$topic_vec->[$i] = 0.0;
	foreach my $id (keys(%{$topic->[$i]})) {
	    if (defined($user_vec->{$id})) {
		$topic_vec->[$i] += $topic->[$i]->{$id};
	    }
	}
    }
    # scale
    my $max_v = 0.0;
    for (my $i = 0; $i < $m; ++$i) {
	if ($max_v < $topic_vec->[$i]) {
	    $max_v = $topic_vec->[$i];
	}
    }
    if ($max_v > 0.0) {
	my $factor = 1.0 / $max_v;
	for (my $i = 0; $i < $m; ++$i) {
	    $topic_vec->[$i] *= $factor;
	}
    }
    return $topic_vec;
}

sub topic_max_idx
{
    my $topic_vector = shift;
    my $i = 0;
    my $max_i = 0;
    my $max_v = 0;
    my $n = scalar(@$topic_vector);
    for ($i = 0; $i < $n; ++$i) {
	if ($max_v < $topic_vector->[$i]) {
	    $max_v = $topic_vector->[$i];
	    $max_i = $i;
	}
    }
    return $max_i;
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

    print "read lang\r";
    
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

    print "read lang\n";

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

  print "read test\r";
  
  open(T, "download/test.txt") or die $!;
  
  print "read test\r";
  
  while (my $line = <T>) {
    chomp($line);
    my $user_id = $line;
    push(@$uid, $user_id);
  }
  close(T);

  print "read test \n";
  
  return $uid;
}

sub repo_rank
{
    my ($repo, $user) = @_;
    my $max_count  = 0;

    print "repo rank\r";

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

    print "repo rank\n";
}

sub sim
{
  my ($v1, $v2) = @_;
  my $dist = 0.0;
  my $n = scalar(@$v1);
  
  for (my $i = 0; $i < $n; ++$i) {
      $dist += ($v1->[$i] - $v2->[$i]) * ($v1->[$i] - $v2->[$i]);
  }
  return $dist;
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
    my @repo_tmp;
    
    foreach my $id (@{$repo->{author}->{$repo->{id}->{$id}->{author}}}) {
	push(@repo_tmp, { rate => $repo->{id}->{$id}->{rate}, id => $id });
    }
    @repo_tmp = sort { $b->{rate} <=> $a->{rate} } @repo_tmp;

    foreach my $rec (@repo_tmp) {
	push(@$author_repo, $rec);
	if (++$n >= 2) {
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
  my ($user, $repo, $topic, $lang, $user_id, $n) = @_;
  my %score_vec;
  my @rec_vec;
  my @dist;
  my @result;
  my ($i, $j, $nn);
  my $nfac = 1.0 / $n;
  my $vec = $user->{all_id}->{$user_id};
  my $topic_vec = topic_vector($topic, $vec);
  
  my @fork_base = get_fork_base($repo, $vec);
  foreach $i (@fork_base) {
      push(@result, $i);
      
      if (@result >= 10) {
	  last;
      }
  }
  
  if (@result < 10) {
      my @author_repo = get_author_repo($repo, $vec);
      foreach $i (@author_repo) {
	  push(@result, $i);
	  
	  if (@result >= 10) {
	      last;
	  }
      }
  }
  
  if (@result < 10) {
      my @topic_word;
      my $max_i = topic_max_idx($topic_vec);
      foreach my $word (keys(%{$topic->[$max_i]})) {
	  push(@topic_word, { likely => $topic->[$max_i]->{$word}, word => $word });
      }
      @topic_word = sort { $b->{likely} <=> $a->{likely} } @topic_word;
      foreach $i (@topic_word) {
	  if (!defined($vec->{$i->{word}})) {
	      push(@result, $i->{word});
	  
	      if (@result >= 10) {
		  last;
	      }
	  }
      }
  }

  return @result;
}

super_testttt:
{
    my $topic = read_topic();
    my $repo = read_repo();
    my $lang = read_lang($repo);
    my $user = read_user($repo, $lang, $topic);
    my $test = read_test();
    my $count = 0;
    
    repo_rank($repo, $user);
    
    open(O, ">results.txt") or die $!;
    select(O);$|=1;select(STDOUT);
    
    foreach my $uid (@$test) {
	printf("recommend %.02f%%..\r", 100 * $count / scalar(@$test));
	
	my @result = recommend_repo($user, $repo, $topic, $lang, $uid, 100);
	print O $uid, ":", join(",", @result), "\n";
	#print $uid, ":", join(",", @result), "\n";
	++$count;
    }
    close(O);
}
