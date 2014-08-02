#!/usr/bin/env perl
# Copyright 2014 Michal Špaček <tupinek@gmail.com>

# Pragmas.
use strict;
use warnings;

# Modules.
use Database::DumpTruck;
use Encode qw(decode_utf8 encode_utf8);
use English;
use HTML::TreeBuilder;
use LWP::UserAgent;
use URI;

# Constants.
my $DATE_WORD_HR = {
	decode_utf8('leden') => 1,
	decode_utf8('únor') => 2,
	decode_utf8('březen') => 3,
	decode_utf8('duben') => 4,
	decode_utf8('květen') => 5,
	decode_utf8('červen') => 6,
	decode_utf8('červenec') => 7,
	decode_utf8('srpen') => 8,
	decode_utf8('září') => 9,
	decode_utf8('říjen') => 10,
	decode_utf8('listopad') => 11,
	decode_utf8('prosinec') => 12,
};

# Don't buffer.
$OUTPUT_AUTOFLUSH = 1;

# URI of service.
my $base_uri = URI->new('http://www.sever.brno.cz/severnik.html');

# Open a database handle.
my $dt = Database::DumpTruck->new({
	'dbname' => 'data.sqlite',
	'table' => 'data',
});

# Create a user agent object.
my $ua = LWP::UserAgent->new(
	'agent' => 'Mozilla/5.0',
);

# Get base root.
print 'Page: '.$base_uri->as_string."\n";
my $root = get_root($base_uri);

# Look for items.
my $act_year = (localtime)[5] + 1900;
foreach my $year (2008 .. $act_year - 1) {
	print "$year\n";
	my $year_div = get_h3_content('Archiv '.$year);
	process_year_block($year, $year_div);
}
# TODO Proc nestahuje?
#print "$act_year\n";
#my $act_year_div = get_h3_content(decode_utf8('Aktuální vydání ').$act_year);
#process_year_block($act_year, $act_year_div);

# Decode month.
sub decode_month {
	my $month = shift;
	if (defined $DATE_WORD_HR->{$month}) {
		return ($DATE_WORD_HR->{$month});
	} else {
		my @month;
		foreach my $month_word (sort { length $b <=> length $a }
			keys %{$DATE_WORD_HR}) {

			$month =~ s/$month_word/$DATE_WORD_HR->{$month_word}/gms;
			@month = split m/-/ms, $month;
		}
		return @month;
	}
}

# Get content after h3 defined by title.
sub get_h3_content {
	my $title = shift;
	my @a = $root->find_by_tag_name('a');
	my $ret_a;
	foreach my $a (@a) {
		if ($a->as_text eq $title) {
			$ret_a = $a;
			last;
		}
	}
	my @content = $ret_a->parent->parent->parent->content_list;
	my $num = 0;
	foreach my $content (@content) {
		if ($num == 1) {
			return $content;
		}
		if (check_h3($content, $title)) {
			$num = 1;
		}
	}
	return;
}

# Check if is h3 with defined title.
sub check_h3 {
	my ($block, $title) = @_;
	foreach my $a ($block->find_by_tag_name('a')) {
		if ($a->as_text eq $title) {
			return 1;
		}
	}
	return 0;
}

# Get root of HTML::TreeBuilder object.
sub get_root {
	my $uri = shift;
	my $get = $ua->get($uri->as_string);
	my $data;
	if ($get->is_success) {
		$data = $get->content;
	} else {
		die "Cannot GET '".$uri->as_string." page.";
	}
	my $tree = HTML::TreeBuilder->new;
	$tree->parse(decode_utf8($data));
	return $tree->elementify;
}

# Process year block.
sub process_year_block {
	my ($year, $year_div) = @_;
	my @a = $year_div->find_by_tag_name('a');
	foreach my $a (@a) {
		my $month = lc($a->as_text);
		remove_trailing(\$month);
		if ($month =~ m/^\s*$/ms) {
			next;
		}
		print '- '.encode_utf8($month)."\n";
		foreach my $month_part (decode_month($month)) {
			# TODO Update.
			$dt->insert({
				'Year' => $year,
				'PDF_link' => $base_uri->scheme.'://'.$base_uri->host.
					$a->attr('href'),
				'Month' => $month_part,
			});
		}
	}
}

# Removing trailing whitespace.
sub remove_trailing {
	my $string_sr = shift;
	${$string_sr} =~ s/^\s*//ms;
	${$string_sr} =~ s/\s*$//ms;
	return;
}
