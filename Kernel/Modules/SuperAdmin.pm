# --
# Kernel/Modules/SuperAdmin.pm - frontend module
# Copyright (C) 2021 Othmar Wigger <othmar.wigger@terreactive.ch>
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Modules::SuperAdmin;

use strict;
use Kernel::System::SuperAdmin;

use Kernel::System::CustomerUser;
use Kernel::System::CustomerGroup;
use Kernel::System::Web::UploadCache;
use Kernel::System::State;

#######################################################################
### Globals

# copied from config.pm
my %DoneTypes = ();
my %TicketTypes = ();
my %TicketSubStates = ();

my %Priorities = ();
my %StatesByID = ();
my %StatesByName = ();
my $TicketSubStatesundef = "false";

#######################################################################

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # set debug
    $Self->{Debug} = 1;

    return $Self;
}

# gets called on click on button or called by action
# decide what work we have to do
sub Run {
    my ( $Self, %Param ) = @_;

    my $SuperAdminObject = $Kernel::OM->Get('Kernel::System::SuperAdmin');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $Output = $LayoutObject->Header(Title => "Super Admin");
    $Output .= $LayoutObject->NavigationBar();

    if ( $Self->isCustomer() ) {
        $Output .= $LayoutObject->Error(
            Message => "You got no permission.",
            Comment => 'Must be Agent to use this',
        );
        return($Output);
    }

    if ( ! $Self->isSuperAdmin() ) {
        $Output .= $LayoutObject->Error(
            Message => "You got no permission.",
            Comment => 'Must be member of the group _SuperAdmin to use this',
        );
        return($Output);
    }

    # globals %StatesByID and %StatesByName
    $Self->GetStates();

    # ticket state types:
    %DoneTypes = (
        0 => 'invalid',
        1 => 'satisfied',
        2 => 'partially satisfied',
        3 => 'dissatisfied',
        4 => 'Auto',
    );

    # ticket types
    my $TypeObject = $Kernel::OM->Get('Kernel::System::Type');
    %TicketTypes = $TypeObject->TypeList();

    # ticket types
    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');
    %Priorities = $PriorityObject->PriorityList();

    $Param{ArticleID} = $ParamObject->GetParam(Param => 'ArticleID');
    $Param{TicketID} = $ParamObject->GetParam(Param => 'TicketID');
# TODO: do we have to output anything a this point?
#   $Output .=  $LayoutObject->Output(
#       TemplateFile => 'SuperAdmin',
#       Data => \%Param );

    # This was something specific for customer number 471.106.
    # Should maybe use a dynamic field?
    my %TicketSubStates = (
        1 => 'New',
        2 => 'InitialReport',
        3 => 'Standby',
        4 => 'ResearchRemote',
        5 => 'ResearchOnsite',
        6 => 'InsuranceCoverage',
        7 => 'CheckInvoiceOffer',
        8 => 'CustomerCare',
        9 => 'FinalReport',
        10 => 'DesktopAssessment',
        11 => 'OnsiteAssessment',
    );

    if ($Self->{Subaction} eq "ArticleShow") {
        $Output .= $Self->ArticleShow();
    } elsif ($Self->{Subaction} eq "ArticleEdit") {
        # ArticleEdit will return redirect to ArticleShow
        $Output = $Self->ArticleEdit();
        return($Output);
    } elsif ($Self->{Subaction} eq "TicketChangeTitle") {
        $Output = $Self->TicketChangeTitle();
    } elsif ($Self->{Subaction} eq "TicketShow") {
        $Output .= $Self->TicketShow();
    } elsif ($Self->{Subaction} eq "TicketChangeFreeText") {
        $Output = $Self->TicketChangeFreeText();
        return($Output);
    } elsif ($Self->{Subaction} eq "TicketChangePriority") {
        $Output = $Self->TicketChangePriority();
        return($Output);
    } elsif ($Self->{Subaction} eq "TicketChangeDueDate") {
        $Output = $Self->TicketChangeDueDate();
        return($Output);
    } elsif ($Self->{Subaction} eq "TicketChangeState") {
        $Output = $Self->TicketChangeState();
        return($Output);
    } elsif ($Self->{Subaction} eq "TicketChangeTAData") {
        $Output = $Self->TicketChangeTAData();
        return($Output);
    } elsif ($Self->{Subaction} eq "TicketDelete") {
        $Output = $Self->TicketDelete();
        return($Output);
    } elsif ($Self->{Subaction} eq "ShowLastTickets") {
        $Output .= $Self->ShowLastTickets();
    } else {
        $Output .= ""
    }

    $Output .=  $LayoutObject->Output(
        TemplateFile => 'SuperAdmin',
    ) . $LayoutObject->Footer();
    return ($Output);
}

sub GetStates() {
    my $Self = shift;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $StateObject = $Kernel::OM->Get('Kernel::System::State');
    %StatesByID = $StateObject->StateList(
        UserID => $Self->{UserID},
    );
    %StatesByName = reverse %StatesByID;
}

sub TicketDelete() {
    my $Self = shift;
    my $Output = '';

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %GetParam = ();
    foreach (qw(TicketID)) {
        $GetParam{$_} = $ParamObject->GetParam(Param => $_);
    }
    unless ( isNumeric($GetParam{TicketID})  ) {
        $Output .= $LayoutObject->Redirect(
            OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID},
        );
        return($Output);
    }

    # change state
    my %Ticket = $TicketObject->TicketGet( TicketID => $GetParam{TicketID}, );
    $Self->TicketChangeStateDB($GetParam{TicketID}, $StatesByName{"Closed"});

    $TicketObject->TicketTitleUpdate(
        Title => "Invalid (was: " . $Ticket{Title} . " )",
        TicketID => $GetParam{TicketID},
        UserID => 1,
    );

    #TODO: do not assume article is in DB
    #my $SQL = 'UPDATE article SET a_body = "INVALID" WHERE ticket_id = ' . $GetParam{TicketID};
    #if ($DBObject->Do(SQL => $SQL)) {
    #}

    $Output .= $LayoutObject->Redirect(
        OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID},
    );
    return ($Output);
}

# changes the title of the ticket and all its articles to a string
sub TicketChangeTitle {
    my $Self = shift;
    my $Output = '';

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %GetParam = ();
    foreach (qw(TicketID Title)) {
        $GetParam{$_} = $ParamObject->GetParam(Param => $_);
    }
    unless ( isNumeric($GetParam{TicketID})  ) {
        $Output .= $LayoutObject->Redirect(
            OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID},
        );
        return($Output);
    }

    # change state
    my %Ticket = $TicketObject->TicketGet( TicketID => $GetParam{TicketID}, );


    $TicketObject->TicketTitleUpdate(
        Title => $GetParam{Title},
        TicketID => $GetParam{TicketID},
        UserID => 1,
    );


    $Output .= $LayoutObject->Redirect(
        OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID},
    );
    return ($Output);
}

sub ShowLastTickets {
    my $Self = shift;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my $HowMany = $ParamObject->GetParam(Param => 'HowMany');
    my $Output = '';
    my @TicketIDs = ();

    unless (isNumeric($HowMany)) {
        $Output .= $LayoutObject->Error(
            Message => "invalid count",
            Comment => 'tststs',
        );
        return($Output);
    }

    $HowMany = $DBObject->Quote($HowMany, 'Integer');
    my $SQL = "SELECT id FROM ticket ORDER BY id DESC LIMIT $HowMany";
    if ($DBObject->Prepare(SQL => $SQL)) {
        while (my @Row = $DBObject->FetchrowArray()) {
            push (@TicketIDs, $Row[0]);
        }
    }

    $LayoutObject->Block(
        Name => 'SuperAdminTicketList',
        Data => {
            HowMany => $HowMany,
            FoundTickets => scalar(@TicketIDs),
        }
    );

    foreach my $TicketID (@TicketIDs) {
        my %Ticket = $TicketObject->TicketGet(TicketID => $TicketID);

        $LayoutObject->Block(
            Name => 'Row',
            Data => \%Ticket,
        );
    }
}

sub TicketShow {
    my $Self = shift;

    my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my $Output = "";

    my $TicketID = $ParamObject->GetParam(Param => 'TicketID');
    unless (isNumeric($TicketID)) {
        $Output .= $LayoutObject->Error(
            Message => "invalid article id: \"$TicketID\"",
            Comment => 'tststs',
        );
        return($Output);
    }
    unless ( $Self->TicketExist($TicketID) ) {
        $Output .= $LayoutObject->Error(
            Message => "Ticket doesnt exist: \"$TicketID\"",
            Comment => 'tststs',
        );
        return ($Output);
    }
    my %Ticket = $TicketObject->TicketGet(
        TicketID => $TicketID,
        UserID => $Self->{UserID},
    );

    $LayoutObject->Block(
        Name => 'TicketShow',
        Data => {
            %Ticket,
        }
    );

    # States
    foreach my $key (sort keys %StatesByID) {
        $LayoutObject->Block(
            Name => 'State',
            Data => {
                TicketID => $TicketID,
                Key => $key,
                Value => $StatesByID{$key},
            },
        );
    }

    # TODO: ta_accounting is not ported to otrs6 yet)
    # Times
    #my %TimeData = $Self->GetTimeData($TicketID);
    #$LayoutObject->Block(
    #    Name => 'Time',
    #    Data => \%TimeData,
    #);

    # free texts
    $Ticket{'DoneTypeStrg'} = $LayoutObject->BuildSelection(
        Data => \%DoneTypes,
        Name => 'DoneType',
        Sort => 'NumericKey',
        Translation => 0,
        SelectedValue => $Ticket{'TicketFreeText2'},
    );

    if ($Ticket{TicketFreeKey4} ne "") {
        $Ticket{'TicketFreeKey4label'} = $Ticket{'TicketFreeKey4'};
    } else {
        $Ticket{'TicketFreeKey4label'} = "ExternalTN";
    }
    my %TicketTypeSelected;
    if ($Ticket{TicketFreeText7} ne "") {
        $TicketTypeSelected{Selected} = $Ticket{TicketFreeText7};
    } else {
        $TicketTypeSelected{SelectedID} = '0 Operation';
    }
    $Ticket{'TicketTypeStrg'} = $LayoutObject->BuildSelection(
        Data => \%TicketTypes,
        Name => 'TicketType',
        SortBy => 'NumericKey',
        SelectedValue => $Ticket{'TicketFreeText7'},
    );

    $LayoutObject->Block(
        Name => 'FreeText',
        Data => \%Ticket,
    );

    my %Param;
    if (\%TicketSubStates and $TicketSubStatesundef eq "false") {
        $Param{'TicketSubStateStrg'} = $LayoutObject->BuildSelection(
            Name => 'TicketSubState',
            Data => \%TicketSubStates,
            SortBy => 'KeyNumeric',
            SelectedValue => $Ticket{"TicketFreeText8"},
        );
        $LayoutObject->Block(
            Name => 'TicketSubState',
            Data => \%Param,
        );
    }

    # build priority string
    $Ticket{'PriorityStrg'} = $LayoutObject->BuildSelection(
        Data => \%Priorities,
        Name => 'PriorityID',
        SortBy => 'KeyNumeric',
        SelectedValue => $Ticket{Priority} || '2 Normal',
    );
    $LayoutObject->Block(
        Name => 'Priority',
        Data => {
            %Ticket,
        },
    );

    # Due Date
    my ($S, $M, $H, $d, $m, $Y) = localtime($Ticket{RealTillTimeNotUsed});
    $m += 1;
    $Y += 1900;
    $Ticket{DueDate} = "$d.$m.$Y";
    $LayoutObject->Block(
        Name => 'DueDate',
        Data => \%Ticket,
    );

    # Articles
    my @MetaArticles = $ArticleObject->ArticleList(
        TicketID => $TicketID,
    );
    for my $MetaArticle (@MetaArticles) {
        my $ArticleID = $MetaArticle->{'ArticleID'};
        my %Article = $ArticleObject->BackendForArticle(%{$MetaArticle})
            ->ArticleGet(%{$MetaArticle});
        my $AccountedTime = $ArticleObject->ArticleAccountedTimeGet(
            ArticleID => $ArticleID,
        );

        $LayoutObject->Block(
            Name => 'ArticleRow',
            Data => {
                TicketID => $TicketID,
                ArticleID => $Article{ArticleID},
                Subject => $Article{Subject},
                State => $Article{ArticleState},
                TimeUnit => $AccountedTime,
            },
        );
    }
    return($Output);
}

sub ArticleShow {
    my $Self = shift;
    my $Output = "";

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my $ArticleID = $ParamObject->GetParam(Param => 'ArticleID');
    unless (isNumeric($ArticleID)) {
        $Output .= $LayoutObject->Error(
            Message => "invalid article id: \"$ArticleID\"",
            Comment => 'tststs',
        );

        return($Output);
    }

    unless ( $Self->ArticleExist($ArticleID) ) {
        $Output .= $LayoutObject->Error(
            Message => "Article doesnt exist: \"$ArticleID\"",
            Comment => 'tststs',
        );
        return ($Output);
    }

    my %Article = $TicketObject->ArticleGet( ArticleID => $ArticleID );
    $Article{AccountedTime} = $TicketObject->ArticleAccountedTimeGet(
        ArticleID => $ArticleID,
    );

    $Output .=  $LayoutObject->Output(
        TemplateFile => 'SuperAdminArticleShow',
        Data => \%Article );

    return ($Output);
}

sub AddArticle {
    my $Self = shift;
    my $TicketID = shift;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %LastArticle = $TicketObject->ArticleLastCustomerArticle( TicketID => $TicketID,);
    my $UserID = 0;
    my $ArticleID = $TicketObject->ArticleCreate(
        TicketID => $TicketID,
        ArticleType => 'note-internal', # email-external|email-internal|phone|fax|...
        SenderType => 'Agent',        #'customer',         # agent|system|customer
        Subject => $LastArticle{'Subject'},      # required
        Body => '',                 # required
        UserID => $Self->{UserID},
        ContentType => 'text/plain; charset=ISO-8859-15',
        HistoryType => 'AddNote',  # EmailCustomer|Move|AddNote|PriorityUpdate|WebRequestCustomer|...
        HistoryComment => 'a comment',
        NoAgentNotify => 1,            # if you don't want to send agent notifications
        HistoryComment => 'created from ta_overview',
    );
}

sub TicketChangeFreeText {
    my $Self = shift;
    my $Output = '';

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %GetParam = ();
    foreach (qw(TicketID kostenstelle DoneType CostCap ExternalTN TypeOfWork TicketType TicketSubState)) {
        $GetParam{$_} = $ParamObject->GetParam(Param => $_);
    }
    unless ( isNumeric($GetParam{TicketID})  ) {
        $Output .= $LayoutObject->Redirect(
            OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID},
        );
        return($Output);
    }

    # change state
    my %Ticket = $TicketObject->TicketGet( TicketID => $GetParam{TicketID}, );

    # change ticketfreetext
    if ($GetParam{kostenstelle}) {
        if ($Ticket{TicketFreeText1} ne $GetParam{kostenstelle}) {
            $TicketObject->TicketFreeTextSet(
                Counter => 1,
                Key => 'Cost Centre', # optional
                Value => $GetParam{kostenstelle},  # optional
                TicketID => $GetParam{TicketID},
                UserID => $Self->{UserID},
            );
        }
    }

    if ($GetParam{DoneType}) {
        if ($GetParam{DoneType} ne 0 and $Ticket{TicketFreeText2} ne $DoneTypes{$GetParam{DoneType}}) {
            $TicketObject->TicketFreeTextSet(
                Counter => 2,
                Key => 'Rating', # optional
                Value => $DoneTypes{$GetParam{DoneType}},  # optional
                TicketID => $GetParam{TicketID},
                UserID => $Self->{UserID},
            );
        }
    }

    if (defined $GetParam{CostCap} && $GetParam{CostCap} !~ /^\s*$/) {
        if ($Ticket{TicketFreeText3} ne $GetParam{CostCap}) {
            $TicketObject->TicketFreeTextSet(
                Counter => 3,
                Key => 'Cost cap',
                Value => $GetParam{CostCap} + 0,  # force numerical
                TicketID => $GetParam{TicketID},
                UserID => $Self->{UserID},
            );
        }
    }

    if (defined $GetParam{ExternalTN}) {
        if ($Ticket{TicketFreeText4} ne $GetParam{ExternalTN}) {
            $TicketObject->TicketFreeTextSet(
                Counter => 4,
                Key => 'ExternalTN',
                Value => $GetParam{ExternalTN},
                TicketID => $GetParam{TicketID},
                UserID => $Self->{UserID},
            );
        }
    }

    if (defined $GetParam{TypeOfWork}) {
        if ($Ticket{TicketFreeText6} ne $GetParam{TypeOfWork}) {
            $TicketObject->TicketFreeTextSet(
                Counter => 6,
                Key => 'TypeOfWork',
                Value => $GetParam{TypeOfWork},
                TicketID => $GetParam{TicketID},
                UserID => $Self->{UserID},
            );
        }
    }

    if ($GetParam{TicketType}) {
        if ($GetParam{TicketType} ne 0 and $Ticket{TicketFreeText7} ne $TicketTypes{$GetParam{TicketType}}) {
            $TicketObject->TicketFreeTextSet(
                Counter => 7,
                Key => 'TicketType', # optional
                Value => $TicketTypes{$GetParam{TicketType}},  # optional
                TicketID => $GetParam{TicketID},
                UserID => $Self->{UserID},
            );
        }
    }

    if ($GetParam{TicketSubState}) {
      if ($GetParam{TicketSubState} ne 0 and $Ticket{TicketFreeText8} ne $TicketSubStates{$GetParam{TicketSubState}}) {
           $TicketObject->TicketFreeTextSet(
                Counter => 8,
                Key => 'TicketSubState', # optional
                Value => $TicketSubStates{$GetParam{TicketSubState}},  # optional
                TicketID => $GetParam{TicketID},
                UserID => $Self->{UserID},
            );
        }
     }

    $Output .= $LayoutObject->Redirect(
        OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID},
    );
    return ($Output);
}

sub TicketChangePriority {
    my $Self = shift;
    my $Output = '';

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %GetParam = ();
    foreach (qw(TicketID PriorityID)) {
        $GetParam{$_} = $ParamObject->GetParam(Param => $_);
    }
    unless ( isNumeric($GetParam{TicketID})  ) {
        $Output .= $LayoutObject->Redirect(
            OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID},
        );
        return($Output);
    }

    # change state
    my %Ticket = $TicketObject->TicketGet( TicketID => $GetParam{TicketID}, );


    $TicketObject->PrioritySet(
        PriorityID => $GetParam{PriorityID},
        TicketID => $GetParam{TicketID},
        UserID => 1,
    );


    $Output .= $LayoutObject->Redirect(
        OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID},
    );
    return ($Output);
}

sub TicketChangeDueDate {
    my $Self = shift;
    my $Output = '';

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %GetParam = ();
    foreach (qw(TicketID DueDate)) {
        $GetParam{$_} = $ParamObject->GetParam(Param => $_);
    }
    unless ( isNumeric($GetParam{TicketID})  ) {
        $Output .= $LayoutObject->Redirect(
            OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID},
        );
        return($Output);
    }

    # change state
    my %Ticket = $TicketObject->TicketGet( TicketID => $GetParam{TicketID}, );

    my $DueDate = $GetParam{DueDate};
    if ($DueDate =~ /[ 0-3][0-9]\.[01][0-9]\.2[0-9][0-9][0-9]/) {
        $TicketObject->TicketPendingTimeSet(
             Year => substr($DueDate,6,4),
             Month => substr($DueDate,3,2),
             Day => substr($DueDate,0,2),
             Hour => 12,
             Minute => 0,
             TicketID => $GetParam{TicketID},
             UserID => 1,
        );
    }

    $Output .= $LayoutObject->Redirect(
        OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID},
    );
    return ($Output);
}

sub TicketChangeState {
    my $Self = shift;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Output = '';
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my %GetParam = ();
    foreach (qw(TicketID NewState CreateArticleOnStateChange)) {
        $GetParam{$_} = $ParamObject->GetParam(Param => $_);
    }
    unless ( isNumeric($GetParam{TicketID})  ) {
        $Output .= $LayoutObject->Redirect(
            OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID},
        );
        return($Output);
    }

    # change state
    if ($GetParam{NewState}) {
        $Self->TicketChangeStateDB($GetParam{TicketID}, $GetParam{NewState});

        # create article
        if ($GetParam{'CreateArticleOnStateChange'}) {
            $Self->AddArticle($GetParam{TicketID});
        }
    }

    $Output .= $LayoutObject->Redirect(
        OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID},
    );
    return ($Output);
}

sub TicketChangeStateDB {
    my $Self = shift;
    my $TicketID = shift;
    my $NewState = shift;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    my $SQL = "UPDATE ticket " .
        " SET ticket_state_id = $NewState " .
        " WHERE id = $TicketID";
    if ($DBObject->Do(SQL => $SQL)) {
        $LogObject->Log(
            Priority => 'notice',
            Message => "User " . $Self->{UserID} .
                " forcefully changed state of Ticket " .
                $TicketID . " to " . $NewState,
        );
    } else {
        $LogObject->Log(
            Priority => 'error',
            Message => "User " . $Self->{UserID} .
                " tried to forcefully changed state of Ticket " .
                $TicketID . " to " . $NewState .  " but failed",
        );
    }
}

#sub TicketChangeTAData {
#    my $Self = shift;
#
#    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
#    my $Output = '';
#    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
#    my %GetParam = ();
#
#    unless ( isNumeric($TicketID) ) {
#        $Output .= "broken";
#        return($Output);
#    }
#
#    # HTML rocks
#    my $note_sm = $DBObject->Quote($ParamObject->GetParam(Param => "note_sm"));
#    my $note_c1 = $DBObject->Quote($ParamObject->GetParam(Param => "note_c1"));
#    my $note_c1_external = $DBObject->Quote($ParamObject->GetParam(Param => "note_c1_External"));
#    my $note_c2 = $DBObject->Quote($ParamObject->GetParam(Param => "note_c2"));
#    my $note_c2_external = $DBObject->Quote($ParamObject->GetParam(Param => "note_c2_External"));
#    my $note_a1 = $DBObject->Quote($ParamObject->GetParam(Param => "note_a1"));
#    my $note_a2 = $DBObject->Quote($ParamObject->GetParam(Param => "note_a2"));
#
#    my $time_sm_5x10 = $DBObject->Quote($ParamObject->GetParam(Param => "time_sm_5x10"), 'Integer');
#    my $time_sm_7x24 = $DBObject->Quote($ParamObject->GetParam(Param => "time_sm_7x24"), 'Integer');
#    my $time_sm_Travel = $DBObject->Quote($ParamObject->GetParam(Param => "time_sm_Travel"), 'Integer');
#
#    my $time_c1_5x10 = $DBObject->Quote($ParamObject->GetParam(Param => "time_c1_5x10"), 'Integer');
#    my $time_c1_7x24 = $DBObject->Quote($ParamObject->GetParam(Param => "time_c1_7x24"), 'Integer');
#    my $time_c1_Travel = $DBObject->Quote($ParamObject->GetParam(Param => "time_c1_Travel"), 'Integer');
#
#    my $time_c2_5x10 = $DBObject->Quote($ParamObject->GetParam(Param => "time_c2_5x10"), 'Integer');
#    my $time_c2_7x24 = $DBObject->Quote($ParamObject->GetParam(Param => "time_c2_7x24"), 'Integer');
#    my $time_c2_Travel = $DBObject->Quote($ParamObject->GetParam(Param => "time_c2_Travel"), 'Integer');
#
#    my $sitemanager_purchase_price = $ParamObject->GetParam(Param => "sitemanager_purchase_price");
#    my $sitemanager_selling_price = $ParamObject->GetParam(Param => "sitemanager_selling_price");
#    my $ctrl_selling_price = $ParamObject->GetParam(Param => "ctrl_selling_price");
#    $sitemanager_purchase_price =~ /^[0-9]+$/ or $sitemanager_purchase_price = 'NULL';
#    $sitemanager_selling_price =~ /^[0-9]+$/ or $sitemanager_selling_price = 'NULL';
#    $ctrl_selling_price =~ /^[0-9]+$/ or $ctrl_selling_price = 'NULL';
#
#    my $SQL = "UPDATE ta_accounting " .
#              "  SET " .
#              "      sitemanager_time = $time_sm_5x10, " .
#              "      sitemanager_time_7x24 = $time_sm_7x24, " .
#              "      sitemanager_time_Travel = $time_sm_Travel, " .
#              "      ctrl_first_time = $time_c1_5x10, " .
#              "      ctrl_first_time_7x24 = $time_c1_7x24, " .
#              "      ctrl_first_time_Travel = $time_c1_Travel, " .
#              "      ctrl_second_time = $time_c2_5x10, " .
#              "      ctrl_second_time_7x24 = $time_c2_7x24, " .
#              "      ctrl_second_time_Travel = $time_c2_Travel, " .
#              "      sitemanager_note = '$note_sm'," .
#              "      ctrl_first_note = '$note_c1'," .
#              "      ctrl_first_note_external = '$note_c1_external'," .
#              "      ctrl_second_note = '$note_c2'," .
#              "      ctrl_second_note_external = '$note_c2_external'," .
#              "      customeradmin_first_note = '$note_a1'," .
#              "      customeradmin_second_note = '$note_a2'," .
#              "      sitemanager_purchase_price = $sitemanager_purchase_price, " .
#              "      sitemanager_selling_price = $sitemanager_selling_price, " .
#              "      ctrl_selling_price = $ctrl_selling_price" .
#              " WHERE ticketid = $TicketID";
#
#    $DBObject->Do(SQL => $SQL);
#
#    $Output .= $LayoutObject->Redirect(
#        OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $TicketID,
#    );
#    return($Output);
#}

sub ArticleEdit {
    my $Self = shift;
    my $Output = '';

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %GetParam = ();
    foreach (qw(ArticleID Subject From To Cc Body AccountedTime)) {
        $GetParam{$_} = $ParamObject->GetParam(Param => $_);
    }
    # TODO: implement argument checking here

    if (! $Self->ArticleExist( $GetParam{ArticleID}) ) {
        $Output .= $LayoutObject->Error(
            Message => "Article doesnt exist: " . $GetParam{ArticleID},
            Comment => 'tststs',
        );
        return ($Output);
    }

    foreach (qw(Subject From To Cc Body)) {
        if ( $GetParam{$_} && $GetParam{$_} ne '' ) {
            #Note: Key ``Body'', ``Subject'', ``From'', ``To'' and ``Cc'' is implemented.
            $TicketObject->ArticleUpdate(
                ArticleID => $GetParam{ArticleID},
                Key => $_,
                Value => $GetParam{$_},
                UserID => $Self->{UserID},
            );
            $LogObject->Log(
                Priority => 'notice',
                Message => "User " . $Self->{UserID} .
                    " changed \"$_\" from Article " . $GetParam{ArticleID},
            );
        }
    }

    if ($GetParam{AccountedTime} && isNumeric($GetParam{AccountedTime})) {
        my $SQL = "UPDATE time_accounting SET time_unit = " . $GetParam{AccountedTime} .
            " WHERE article_id = " . $GetParam{ArticleID};
        if ($DBObject->Do(SQL => $SQL)) {
            $LogObject->Log(
                Priority => 'notice',
                Message => "User " . $Self->{UserID} .
                    " changed Time from Article " . $GetParam{ArticleID},
            );
        } else {
            $LogObject->Log(
                Priority => 'error',
                Message => "User " . $Self->{UserID} .
                    " failed to changed Time from Article " . $GetParam{ArticleID},
            );
        }
    }

    $Output .= $LayoutObject->Redirect(
        OP => "Action=SuperAdmin&Subaction=ArticleShow&ArticleID=" . $GetParam{ArticleID},
    );
    return($Output);
}

# this is mostly a copy from GetArticleTAData() from ta_overview.pm
sub GetTimeData {
    my $Self        = shift;
    my $TicketID    = shift;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    unless ( isInteger($TicketID) ) {
        $LogObject->Log(
            Priority => 'Error',
            Message => "TicketID non-integer on SQL-reading!"
        );
        return;
    }

    my %tAData = ();
    my %Ticket = $TicketObject->TicketGet( TicketID => $TicketID, );
    my $RealTime = $TicketObject->TicketAccountedTimeGet(%Ticket);
    $RealTime = sprintf("%.3f", $RealTime / 60);
    $tAData{'Accounted Time'} = $RealTime;
    $TicketID = $DBObject->Quote($TicketID, 'Integer');

    $DBObject->Prepare(
        SQL => "SELECT sitemanager_time, sitemanager_time_7x24, sitemanager_time_travel, sitemanager_note, ".
              " ctrl_first_time, ctrl_first_time_7x24, ctrl_first_time_travel, ctrl_first_note, " .
              " ctrl_second_time, ctrl_second_time_7x24, ctrl_second_time_travel, ctrl_second_note, " .
              " customeradmin_first_note, customeradmin_second_note, " .
              " customeradmin_selection, ctrl_first_note_external, ctrl_second_note_external, " .
              " sitemanager_purchase_price, sitemanager_selling_price, ctrl_selling_price " .
              " FROM ta_accounting WHERE ticketid = $TicketID",
    );

    while (my @Row = $DBObject->FetchrowArray()) {
        if ( scalar @Row > 0) {
            $tAData{'Sitemanager_Time_5x10'} = $Row[0];
            $tAData{'Sitemanager_Time_7x24'} = $Row[1];
            $tAData{'Sitemanager_Time_Travel'} = $Row[2];
            $tAData{'Sitemanager_Note'} = $Row[3];

            $tAData{'MSSCtrl_Time_5x10'} = $Row[4];
            $tAData{'MSSCtrl_Time_7x24'} = $Row[5];
            $tAData{'MSSCtrl_Time_Travel'} = $Row[6];
            $tAData{'MSSCtrl_Note'} = $Row[7];
            $tAData{'MSSCtrl_Note_External'} = $Row[15];

            $tAData{'MSSCtrl_Second_Time_5x10'} = $Row[8];
            $tAData{'MSSCtrl_Second_Time_7x24'} = $Row[9];
            $tAData{'MSSCtrl_Second_Time_Travel'} = $Row[10];
            $tAData{'MSSCtrl_Second_Note'} = $Row[11];
            $tAData{'MSSCtrl_Second_Note_External'} = $Row[16];

            $tAData{'Customeradmin_Note'} = $Row[12];
            $tAData{'Customeradmin_Second Note'} = $Row[13];
            $tAData{'Customeradmin_Selection'} = $Row[14];

            $tAData{'Sitemanager_Purchase Price'} = $Row[17];
            $tAData{'Sitemanager_Selling Price'} = $Row[18];
            $tAData{'Controller_Selling Price'} = $Row[19];
        }
    }

    return (%tAData);
}

sub TicketExist {
    my $Self        = shift;
    my $TicketID    = shift;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my $TicketNumber = $TicketObject->TicketNumberLookup(
        TicketID => $TicketID,
        UserID => $Self->{UserID},
    );

    if ($TicketNumber > 0) {
        return(1);
    }

    return(0);
}

sub ArticleExist {
    my $Self = shift;
    my $ArticleID = shift;

    if ( ! isNumeric($ArticleID) ) {
        return(0);
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $SQL = "SELECT id FROM article WHERE id=$ArticleID";
    if ($DBObject->Prepare(SQL => $SQL)) {
        my @Row = $DBObject->FetchrowArray();

        if ($Row[0] eq $ArticleID) {
            return(1);
        }
    }

    return(0);
}

sub isSuperAdmin() {
    my $Self   = shift;

    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');
    return $GroupObject->PermissionCheck(
        UserID => $Self->{UserID},
        GroupName => '_SuperAdmin',
        Type => 'rw',
    );
}

# isCustomer
#
# return true if we are a customer user (in Customer Interface)
#
sub isCustomer() {
    my $Self = shift;

    if ($Self->{UserType} eq "User") {
        return(0)
    } elsif ($Self->{UserType} eq "Customer") {
        return(1)
    } else {
        $Self->LogMe("WTF we arent User or Customer but " . $Self->{UserType} . ", aborting");
        exit;
    }
}

sub isTime($) {
    my $s_input = shift;
    if ($s_input =~ /^[+-]*\d+$/) {
        return (1);
    }
    return (0);
}

sub isNumeric($) {
    my $s_input = shift;
    if ($s_input =~ /^-*\d+$/) {
        return (1);
    }
    return (0);
}

sub isInteger($) {
    my $s_input = shift;

    if ($s_input =~ /^\d+$/) {
        return (1);
    }
    return (0);
}

# LogMe
#
# debug log function
#
# Arguments: the message to log
# Result: message gets logged with debug priority
#
sub LogMe {
    my $Self = shift;
    my $Msg = shift;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $LogObject->Log(
         Priority => 'debug',
         Message => $Msg,
    );
}

1;
