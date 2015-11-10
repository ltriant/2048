#!/usr/bin/env perl
# 2048.pl -- a curses-based 2048 clone with a hint of doge
#
# hjkl to move
# q to quit

package Game::Cell;

use warnings;
use strict;

use Moo;

has value => (is => 'rw');

sub double {
	my ($self) = @_;
	$self->value($self->value * 2);
}

sub as_string {
	my ($self) = @_;

	my %disp = (
		0    => sub { '   .' },
		2    => sub { '   2' },
		4    => sub { '   4' },
		8    => sub { '   8' },
		16   => sub { '  16' },
		32   => sub { '  32' },
		64   => sub { '  64' },
		128  => sub { ' 128' },
		256  => sub { ' 256' },
		512  => sub { ' 512' },
		1024 => sub { '1024' },
		2048 => sub { '2048' },
	);

	return unless exists $disp{$self->value};

	return $disp{$self->value}->();
}

package Game::Board;

use warnings;
use strict;

use Moo;
use List::Util qw/sum0/;
use List::MoreUtils qw/any/;

use constant SIZE => 4;

use constant {
	UP    => 1,
	DOWN  => 2,
	LEFT  => 4,
	RIGHT => 8,
};

has board => (
	is      => 'rw',
	default => sub {
		# SIZE x SIZE board full of zeroes
		my $board = 
			[ map {
				[ map {
					Game::Cell->new(value => 0)
				} 1 .. SIZE ]
			} 1 .. SIZE ];

		# initialise a random cell with a 2
		my ($x, $y) = (int(rand(SIZE)), int(rand(SIZE)));
		$board->[$x]->[$y]->value(2);

		return $board;
	}
);

has score => (
	is      => 'rw',
	default => sub { 0 },
);

sub add_score {
	my ($self, $points) = @_;
	$self->score($self->score + $points);
}

sub up    { pop->move(UP)    }
sub down  { pop->move(DOWN)  }
sub left  { pop->move(LEFT)  }
sub right { pop->move(RIGHT) }

sub empty_tiles { grep { $_->value == 0 } map { @$_ } @{ pop->board } }
sub won { any { $_->value == 2048 } map { @$_ } @{ pop->board } }
sub lost {
	my ($self) = @_;

	return 0 if $self->empty_tiles;

	foreach my $direction (UP, DOWN, LEFT, RIGHT) {
		foreach my $block ($self->blocks_of_tiles($direction)) {
			for (my $i = $#$block; $i > 0; $i--) {
				my $prev = $block->[$i - 1];
				my $cur  = $block->[$i];
				return 0 if ($cur->value == $prev->value) and ($cur->value > 0);
			}
		}
	}

	return 1;
}

# Group the tiles into the rows/columns that we will operate on, based on the
# perspective of the direction we want to move them.
# e.g.
#  We have the following board:
#    [ 1 2 3 ]
#    [ 4 5 6 ]
#    [ 7 8 9 ]
#
# If we're moving tiles up, then we want to operate on the following
# blocks of cells:
#   [ 7 4 1 ]
#   [ 8 5 2 ]
#   [ 9 6 3 ]
#
# If down:
#   [ 1 4 7 ]
#   [ 2 5 8 ]
#   [ 3 6 9 ]
#
# If left:
#   [ 3 2 1 ]
#   [ 6 5 4 ]
#   [ 9 8 7 ]
#
# etc...
sub blocks_of_tiles {
	my ($self, $direction) = @_;

	my @blocks = map {
		my $r = $_;
		[ map {
			my $c = $_;
			if ($direction == UP or $direction == DOWN) {
				# if moving up or down, we operate on columns
				$self->board->[$c]->[$r]
			} else {
				# left or right? operate on rows
				$self->board->[$r]->[$c]
			}
		} 0 .. SIZE - 1 ]
	} 0 .. SIZE - 1;

	if (($direction == UP) or ($direction == LEFT)) {
		@blocks = map { [ reverse @$_ ] } @blocks;
	}

	return @blocks;
}

sub shift_tiles {
	my ($self, $direction) = @_;

	my $moved = 0;

	foreach my $block ($self->blocks_of_tiles($direction)) {
		my $swapped;

		# Process:
		#   For each value in the row/column:
		#     If the current value is a zero and the previous value is not a zero:
		#       Swap the values
		#   Repeat until we have swapped no more values
		#
		# We repeat because, for example, if we have a block: 
		#     [ 2 0 4 0 ]
		#   On the first run, we will end up with:
		#     [ 0 2 0 4 ]
		#   So we keep going another time to end up with:
		#     [ 0 0 2 4 ]
		do {
			$swapped = 0;

			for my $i (1 .. $#$block) {
				my $prev = $block->[$i - 1];
				my $cur  = $block->[$i];

				if (($cur->value == 0) and ($prev->value > 0)) {
					$cur->value($prev->value);
					$prev->value(0);
					$swapped = 1;
				}
			}

			$moved |= $swapped;
		} while ($swapped);
	}

	return $moved;
}

sub merge_tiles {
	my ($self, $direction) = @_;

	my @scores;

	foreach my $block ($self->blocks_of_tiles($direction)) {
		for (my $i = $#$block; $i > 0; $i--) {
			my $cur  = $block->[$i];
			my $prev = $block->[$i - 1];

			if ($cur->value == $prev->value) {
				$cur->double;
				$prev->value(0);
				push @scores => $cur->value;
			}
		}
	}

	return sum0(@scores);
}

sub new_random_tile {
	my ($self) = @_;

	my @empties = $self->empty_tiles;
	return unless @empties;

	$empties[ rand @empties ]->value( [2,4]->[int rand(2)] );

	return 1;
}

sub move {
	my ($self, $direction) = @_;

	my $moved = 0;

	$moved |= $self->shift_tiles($direction);

	$moved |= my $points = $self->merge_tiles($direction);
	$self->add_score($points);

	$moved |= $self->shift_tiles($direction);

	$self->new_random_tile if $moved;
}

sub as_string {
	my ($self) = @_;

	my $str = '';

	foreach my $row (@{ $self->board }) {
		$str .= join '   ', map { $_->as_string } @$row;
		$str .= "\n";
	}

	return $str;
}

package main;

use warnings;
use strict;

use Curses::UI;

my $board = Game::Board->new;

my $cui = Curses::UI->new(-color_support => 1, -clear_on_exit => 1);

my $status_w = $cui->add('status_w', 'Window');
my $status = $status_w->add('status', 'TextViewer',
	-text     => '2048 - wow. such clone.',
	-fg       => 'yellow',
	-ipadleft => 3,
);

my $main_w = $cui->add('main_w', 'Window',
	-padtop => 1,
);
my $canvas = $main_w->add('canvas', 'TextViewer',
	-title  => 'score: 0',
	-text   => $board->as_string,
	-height => 6,
	-width  => 29,
	-border => 1,
	-bfg    => 'blue',
);

$canvas->focus;

sub move {
	my ($d) = @_;

	my %disp = (
		k => sub { $board->up    },
		j => sub { $board->down  },
		h => sub { $board->left  },
		l => sub { $board->right },
	);

	return unless exists $disp{$d};

	$disp{$d}->();
	$canvas->text($board->as_string);
	$canvas->title('score: ' . $board->score);

	if ($board->won)  {
		$cui->dialog("Wow. Much win. Such 2048. Starting new game...");
		$board = Game::Board->new;
		$canvas->text($board->as_string);
		$canvas->title('score: ' . $board->score);
	}

	if ($board->lost) {
		$cui->dialog("Much lose! Starting new game...");
		$board = Game::Board->new;
		$canvas->text($board->as_string);
		$canvas->title('score: ' . $board->score);
	}
}

$cui->set_binding( sub { exit }, 'q' );
$cui->set_binding( sub { move('h') }, 'h' );
$cui->set_binding( sub { move('j') }, 'j' );
$cui->set_binding( sub { move('k') }, 'k' );
$cui->set_binding( sub { move('l') }, 'l' );

$cui->mainloop;

__DATA__


                  Y.                      _
                  YiL                   .```.
                  Yii;      WOW       .; .;;`.
                  YY;ii._           .;`.;;;; :
                  iiYYYYYYiiiii;;;;i` ;;::;;;;
              _.;YYYYYYiiiiiiYYYii  .;;.   ;;;
           .YYYYYYYYYYiiYYYYYYYYYYYYii;`  ;;;;
         .YYYYYYY$$YYiiYY$$$$iiiYYYYYY;.ii;`..
        :YYY$!.  TYiiYY$$$$$YYYYYYYiiYYYYiYYii.
        Y$MM$:   :YYYYYY$!"``"4YYYYYiiiYYYYiiYY.
     `. :MM$$b.,dYY$$Yii" :'   :YYYYllYiiYYYiYY
  _.._ :`4MM$!YYYYYYYYYii,.__.diii$$YYYYYYYYYYY
  .,._ $b`P`     "4$$$$$iiiiiiii$$$$YY$$$$$$YiY;
     `,.`$:       :$$$$$$$$$YYYYY$$$$$$$$$YYiiYYL
      "`;$$.    .;PPb$`.,.``T$$YY$$$$YYYYYYiiiYYU:
    ' ;$P$;;: ;;;;i$y$"!Y$$$b;$$$Y$YY$$YYYiiiYYiYY
      $Fi$$ .. ``:iii.`-";YYYYY$$YY$$$$$YYYiiYiYYY
      :Y$$rb ````  `_..;;i;YYY$YY$$$$$$$YYYYYYYiYY:
       :$$$$$i;;iiiiidYYYYYYYYYY$$$$$$YYYYYYYiiYYYY.
        `$$$$$$$YYYYYYYYYYYYY$$$$$$YYYYYYYYiiiYYYYYY
        .i!$$$$$$YYYYYYYYY$$$$$$YYY$$YYiiiiiiYYYYYYY
       :YYiii$$$$$$$YYYYYYY$$$$YY$$$$YYiiiiiYYYYYYi' cmang
