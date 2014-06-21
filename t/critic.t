#!perl
#===============================================================================
#
# t/critic.t
#
# DESCRIPTION
#   Test script to check Perl::Critic conformance.
#
# COPYRIGHT
#   Copyright (C) 2014 Steve Hay.  All rights reserved.
#
# LICENCE
#   You may distribute under the terms of either the GNU General Public License
#   or the Artistic License, as specified in the LICENCE file.
#
#===============================================================================

use 5.008001;

use strict;
use warnings;

use Test::More;

#===============================================================================
# MAIN PROGRAM
#===============================================================================

MAIN: {
    my $ok = eval {
        require Test::Perl::Critic;
        Test::Perl::Critic->import();
        1;
    };

    if (not $ok) {
        plan skip_all => 'Test::Perl::Critic required to test with Perl::Critic';
    }
    else {
        all_critic_ok('.');
    }
}

#===============================================================================
