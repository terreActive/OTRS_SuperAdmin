# --
# Kernel/System/SuperAdmin.pm - core module
# Copyright (C) 2021 Othmar Wigger <othmar.wigger@terreactive.ch>
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::System::SuperAdmin;

use strict;
use warnings;

# list your object dependencies here
our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Group',
    'Kernel::System::CustomerGroup',
);

sub new {
    my $Type  = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless ($Self, $Type);

    return $Self;
}

1;
