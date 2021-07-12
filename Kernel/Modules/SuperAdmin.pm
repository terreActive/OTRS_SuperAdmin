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
use Kernel::System::VariableCheck qw(IsHashRefWithData);

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
            Comment => 'Must be Agent to use this'
        );
        return($Output);
    }

    if ( ! $Self->isSuperAdmin() ) {
        $Output .= $LayoutObject->Error(
            Message => "You got no permission.",
            Comment => 'Must be member of the group _SuperAdmin to use this'
        );
        return($Output);
    }

    # states
    $Self->GetStates();


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
        $Output = $Self->ArticleEdit();
        return($Output);
    } elsif ($Self->{Subaction} eq "TicketChangeTitle") {
        $Output = $Self->TicketChangeTitle();
    } elsif ($Self->{Subaction} eq "TicketShow") {
        $Output .= $Self->TicketShow();
    } elsif ($Self->{Subaction} eq "TicketChangePriority") {
        $Output = $Self->TicketChangePriority();
        return($Output);
    } elsif ($Self->{Subaction} eq "TicketChangeDueDate") {
        $Output = $Self->TicketChangeDueDate();
        return($Output);
    } elsif ($Self->{Subaction} eq "TicketChangeState") {
        $Output = $Self->TicketChangeState();
        return($Output);
    } elsif ($Self->{Subaction}  =~ /^TicketAddDynamicField_/) {
        $Output = $Self->TicketAddDynamicField();
        return($Output);
    } elsif ($Self->{Subaction}  =~ /^TicketUpdateDynamicField_/) {
        $Output = $Self->TicketUpdateDynamicField();
        return($Output);
    } elsif ($Self->{Subaction}  =~ /^TicketDeleteDynamicField_/) {
        $Output = $Self->TicketDeleteDynamicField();
        return($Output);
    } elsif ($Self->{Subaction} eq "ShowLastTickets") {
        $Output .= $Self->ShowLastTickets();
    } else {
        $Output .= ""
    }

    $Output .=  $LayoutObject->Output(
        TemplateFile => 'SuperAdmin'
    ) . $LayoutObject->Footer();
    return ($Output);
}

sub GetStates() {
    my $Self = shift;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $StateObject = $Kernel::OM->Get('Kernel::System::State');
    %StatesByID = $StateObject->StateList(
        UserID => $Self->{UserID}
    );
    %StatesByName = reverse %StatesByID;
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
    unless (isNumeric($GetParam{TicketID})) {
        $Output .= $LayoutObject->Redirect(
            OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID}
        );
        return($Output);
    }

    my %Ticket = $TicketObject->TicketGet(TicketID => $GetParam{TicketID});

    $TicketObject->TicketTitleUpdate(
        Title => $GetParam{Title},
        TicketID => $GetParam{TicketID},
        UserID => $Self->{UserID}
    );


    $Output .= $LayoutObject->Redirect(
        OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID}
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
            Comment => 'tststs'
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
            FoundTickets => scalar(@TicketIDs)
        }
    );

    foreach my $TicketID (@TicketIDs) {
        my %Ticket = $TicketObject->TicketGet(TicketID => $TicketID);

        $LayoutObject->Block(
            Name => 'Row',
            Data => \%Ticket
        );
    }
}

sub TicketShow {
    my $Self = shift;

    my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $Output = "";

    my $TicketID = $ParamObject->GetParam(Param => 'TicketID');
    unless (isNumeric($TicketID) && $Self->TicketExist($TicketID)) {
        $Output .= $LayoutObject->Error(
            Message => "Ticket doesn't exist: \"$TicketID\"",
            Comment => 'tststs'
        );
        return ($Output);
    }
    my %Ticket = $TicketObject->TicketGet(
        TicketID => $TicketID,
        UserID => $Self->{UserID},
        DynamicFields => $Self->{UserID}
    );

    $LayoutObject->Block(
        Name => 'TicketShow',
        Data => {
            %Ticket
        }
    );

    foreach my $key (sort keys %StatesByID) {
        $LayoutObject->Block(
            Name => 'State',
            Data => {
                TicketID => $TicketID,
                Key => $key,
                Value => $StatesByID{$key}
            }
        );
    }

    $Ticket{States} = $LayoutObject->BuildSelection(
        Data => \%StatesByID,
        Name => 'NewState',
        SortBy => 'KeyNumeric',
        Class => 'Modernize W10pc',
        SelectedValue => $Ticket{'State'}
    );

    $LayoutObject->Block(
        Name => 'States',
        Data => \%Ticket
    );

    my %Param;

    # build priority string
    $Ticket{'PriorityStrg'} = $LayoutObject->BuildSelection(
        Data => \%Priorities,
        Name => 'PriorityID',
        SortBy => 'KeyNumeric',
        Class => 'Modernize W10pc',
        SelectedValue => $Ticket{Priority} || '2 Normal'
    );
    $LayoutObject->Block(
        Name => 'Priority',
        Data => {
            %Ticket
        }
    );

    # Articles
    my @MetaArticles = $ArticleObject->ArticleList(
        TicketID => $TicketID
    );
    for my $MetaArticle (@MetaArticles) {
        my $ArticleID = $MetaArticle->{'ArticleID'};
        my %Article = $ArticleObject->BackendForArticle(%{$MetaArticle})
            ->ArticleGet(%{$MetaArticle});
        my $AccountedTime = $ArticleObject->ArticleAccountedTimeGet(
            ArticleID => $ArticleID
        );

        $LayoutObject->Block(
            Name => 'ArticleRow',
            Data => {
                TicketID => $TicketID,
                ArticleID => $Article{ArticleID},
                Subject => $Article{Subject},
                TimeUnit => $AccountedTime
            },
        );
    }

    # get the dynamic fields for ticket object
    my $DynamicFields = $DynamicFieldObject->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Ticket']
    );

    # to store dynamic fields to be displayed in the process widget and in the sidebar ? 
    my (@Fields); #

    # cycle trough all Dynamic Fields for ticket object
    DYNAMICFIELD:
    for my $DynamicFieldConfig (@{$DynamicFields}) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if $DynamicFieldConfig->{Name} eq "ProcessManagementActivityID";
        next DYNAMICFIELD if $DynamicFieldConfig->{Name} eq "ProcessManagementProcessID";

        $DynamicFieldConfig->{Defined} = defined $Ticket{'DynamicField_' . $DynamicFieldConfig->{Name}} ? 1 : 0;

        # use translation here to be able to reduce the character length in the template
        my $Label = $LayoutObject->{LanguageObject}->Translate($DynamicFieldConfig->{Label});

        my $ValueStrg = $DynamicFieldBackendObject->DisplayValueRender(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Ticket{'DynamicField_' . $DynamicFieldConfig->{Name}},
            LayoutObject       => $LayoutObject
        );

        push @Fields, {
            "DynamicField_$DynamicFieldConfig->{Name}" => $ValueStrg->{Title},
            $DynamicFieldConfig->{Name}                => $ValueStrg->{Title},
            Value                                      => $ValueStrg->{Value},
            FieldID                                    => $DynamicFieldConfig->{ID},
            Name                                       => $DynamicFieldConfig->{Name},
            Type                                       => $DynamicFieldConfig->{FieldType},
            Config                                     => $DynamicFieldConfig->{Config},
            Defined                                    => $DynamicFieldConfig->{Defined},
            RegExErrorMessage                          => $DynamicFieldConfig->{Config}->{RegExList}[0]->{ErrorMessage},
            RegEx                                      => $DynamicFieldConfig->{Config}->{RegExList}[0]->{Value},
            Label                                      => $Label
        };
    }

    for my $field (@Fields) {
        if ($field->{Defined}) {
            if ($field->{Type} eq "Text") {
                $LayoutObject->Block(
                    Name => 'TicketDynamicFieldText',
                    Data => $field
                );
            }
            if ($field->{Type} eq "Dropdown") {
                my $PossibleValues = $field->{Config}->{PossibleValues};
                $field->{PossibleValues} = $LayoutObject->BuildSelection(
                    Data => $PossibleValues,
                    Name => "TicketDynamicFieldValue_" . $field->{FieldID},
                    SortBy => 'KeyNumeric',
                    Class => 'Modernize W10pc',
                    SelectedValue => $field->{Value} || $PossibleValues->{$field->{Config}->{DefaultValue}}
                );
                $LayoutObject->Block(
                    Name => 'TicketDynamicFieldDropdown',
                    Data => $field
                );
            }
            if ($field->{Type} eq "Date") {
                # Due Date
                my ($d, $m, $Y) = split(/\//, $field->{Value});

                my $Prefix = "TicketDynamicFieldValue_" . $field->{FieldID} . "_";
                $field->{Date} = $LayoutObject->BuildDateSelection(
                    Prefix => $Prefix,
                    $Prefix . "Year" => $Y,
                    $Prefix . "Month" => $m,
                    $Prefix . "Day" => $d
                );
                $LayoutObject->Block(
                    Name => 'TicketDynamicFieldDate',
                    Data => $field
                );
            }
        } else {
            $LayoutObject->Block(
                Name => 'TicketDynamicFieldTextAdd',
                Data => $field
            );
        }
    }
    return($Output);
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
    unless (isNumeric($GetParam{TicketID})) {
        $Output .= $LayoutObject->Redirect(
            OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID}
        );
        return($Output);
    }

    # change state
    my %Ticket = $TicketObject->TicketGet(TicketID => $GetParam{TicketID});


    $TicketObject->PrioritySet(
        PriorityID => $GetParam{PriorityID},
        TicketID => $GetParam{TicketID},
        UserID => $Self->{UserID}
    );


    $Output .= $LayoutObject->Redirect(
        OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID}
    );
    return ($Output);
}

sub TicketChangeState {
    my $Self = shift;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my $Output = '';
    my %GetParam = ();

    foreach (qw(TicketID NewState CreateArticleOnStateChange)) {
        $GetParam{$_} = $ParamObject->GetParam(Param => $_);
    }

    unless ( isNumeric($GetParam{TicketID})  ) {
        $Output .= $LayoutObject->Redirect(
            OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID}
        );
        return($Output);
    }

    # change state
    if ($GetParam{NewState}) {
        $TicketObject->TicketStateSet(
            StateID  => $GetParam{NewState},
            TicketID => $GetParam{TicketID},
            UserID   => $Self->{UserID},
            SendNoNotification => 0
        );

        # create article
        if ($GetParam{'CreateArticleOnStateChange'}) {
            $Self->AddArticle($GetParam{TicketID});
        }
    }

    $Output .= $LayoutObject->Redirect(
        OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID}
    );
    return ($Output);
}

sub TicketAddDynamicField {
    my $Self = shift;

    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $DynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::DynamicFieldValue');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    my $Output = '';
    my %GetParam = ();

    foreach (qw(TicketID Subaction)) {
        $GetParam{$_} = $ParamObject->GetParam(Param => $_);
    }

    unless (isNumeric($GetParam{TicketID})) {
        $Output .= $LayoutObject->Redirect(
            OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID}
        );
        return($Output);
    }

    my $DynamicFieldID = $GetParam{Subaction};
    $DynamicFieldID =~ s/TicketAddDynamicField_//;

    my $DynamicField = $DynamicFieldObject->DynamicFieldGet(
        ID => $DynamicFieldID
    );

    my $DynamicFieldType = $DynamicField->{FieldType};
    my %Value;
    if ($DynamicFieldType eq "Date") {
        $Value{ValueDateTime} = DateTime->now->strftime('%Y-%m-%d %H:%M:%S');
    } else {
        $Value{ValueText} = '-';
    }

    $DynamicFieldValueObject->ValueSet(
        FieldID => $DynamicFieldID,
        ObjectID => $GetParam{TicketID},
        UserID => $Self->{UserID},
        Value => [
            \%Value
        ]
    );

    $Output .= $LayoutObject->Redirect(
        OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID}
    );
    return ($Output);
}

sub TicketUpdateDynamicField {
    my $Self = shift;

    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $DynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::DynamicFieldValue');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    my $Output = '';
    my %GetParam = ();

    foreach (qw(TicketID Subaction)) {
        $GetParam{$_} = $ParamObject->GetParam(Param => $_);
    }

    unless ( isNumeric($GetParam{TicketID})  ) {
        $Output .= $LayoutObject->Redirect(
            OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID}
        );
        return($Output);
    }

    my $DynamicFieldID = $GetParam{Subaction};
    $DynamicFieldID =~ s/TicketUpdateDynamicField_//;

    my $DynamicField = $DynamicFieldObject->DynamicFieldGet(
        ID   => $DynamicFieldID
    );

    my $DynamicFieldType = $DynamicField->{FieldType};
    my %Value;
    if ($DynamicFieldType eq "Date") {
        my $Year = $ParamObject->GetParam(Param => "TicketDynamicFieldValue_" . $DynamicFieldID . "_Year");
        my $Month = "0" . $ParamObject->GetParam(Param => "TicketDynamicFieldValue_" . $DynamicFieldID . "_Month");
        my $Day = $ParamObject->GetParam(Param => "TicketDynamicFieldValue_" . $DynamicFieldID . "_Day");
        $Value{ValueDateTime} = DateTime->new(year => $Year, month => $Month, day => $Day)->strftime('%Y-%m-%d %H:%M:%S');
    } else {
        $Value{ValueText} = $ParamObject->GetParam(Param => "TicketDynamicFieldValue_$DynamicFieldID");
    }

    my $RegEx = $DynamicField->{Config}->{RegExList}[0]->{Value};

    if (!$RegEx or $Value{ValueText} =~ $RegEx) {
        $DynamicFieldValueObject->ValueSet(
            FieldID => $DynamicFieldID,
            ObjectID => $GetParam{TicketID},
            UserID => $Self->{UserID},
            Value => [
                \%Value
            ]
        );
    } else {
        $Output .= $LayoutObject->Redirect(
            OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID}
        );
        return($Output);
    }

    $Output .= $LayoutObject->Redirect(
        OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID}
    );
    return ($Output);
}

sub TicketDeleteDynamicField {
    my $Self = shift;

    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $DynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::DynamicFieldValue');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    my $Output = '';
    my %GetParam = ();

    foreach (qw(TicketID Subaction)) {
        $GetParam{$_} = $ParamObject->GetParam(Param => $_);
    }
    unless ( isNumeric($GetParam{TicketID})  ) {
        $Output .= $LayoutObject->Redirect(
            OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID}
        );
        return($Output);
    }
    my $DynamicFieldID = $GetParam{Subaction};
    $DynamicFieldID =~ s/TicketDeleteDynamicField_//;

    $DynamicFieldValueObject->ValueDelete(
        FieldID => $DynamicFieldID,
        ObjectID => $GetParam{TicketID},
        UserID => $Self->{UserID}
    );

    $Output .= $LayoutObject->Redirect(
        OP => "Action=SuperAdmin&Subaction=TicketShow&TicketID=" . $GetParam{TicketID}
    );
    return ($Output);
}

sub ArticleShow {
    my $Self = shift;
    my $Output = "";

    my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my $ArticleID = $ParamObject->GetParam(Param => 'ArticleID');
    unless (isNumeric($ArticleID) && $Self->ArticleExist($ArticleID)) {
        $Output .= $LayoutObject->Error(
            Message => "Article doesn't exist: \"$ArticleID\"",
            Comment => 'tststs'
        );
        return ($Output);
    }

    my $TicketID = $ArticleObject->TicketIDLookup(
        ArticleID => $ArticleID
    );
    my %Article = $ArticleObject->BackendForArticle( TicketID => $TicketID, ArticleID => $ArticleID)->ArticleGet( TicketID => $TicketID, ArticleID => $ArticleID );
    $Article{AccountedTime} = $ArticleObject->ArticleAccountedTimeGet(
        ArticleID => $ArticleID
    );

    $LayoutObject->Block(
        Name => 'ArticleShow',
        Data => \%Article
    );

    return ($Output);
}

sub AddArticle {
    my $Self = shift;
    my $TicketID = shift;

    my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    
    my @LastArticle = $ArticleObject->ArticleList(
        TicketID => $TicketID,
        OnlyLast => 1
    );

    my $ArticleID = $LastArticle[0]->{ArticleID};

    my $ArticleBackendObject = $ArticleObject->BackendForArticle(
        TicketID  => $TicketID,
        ArticleID => $ArticleID
    );

    my %Article = $ArticleBackendObject->ArticleGet(
        TicketID => $TicketID,
        ArticleID => $ArticleID
    );

    $ArticleBackendObject->ArticleCreate(
        TicketID       => $TicketID,
        SenderTypeID   => 1,
        IsVisibleForCustomer => 1,
        ArticleType    => 'note-internal',
        Subject        => $Article{Subject},
        Body           => '',
        UserID         => $Self->{UserID},
        ContentType    => 'text/plain; charset=ISO-8859-15',
        HistoryType    => 'AddNote',
        HistoryComment => 'a comment',
        NoAgentNotify  => 1,
        HistoryComment => 'created from ta_overview'
    );
}

sub ArticleEdit {
    my $Self = shift;
    my $Output = '';

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %GetParam = ();
    foreach (qw(ArticleID Subject From To Cc Body AccountedTime)) {
        $GetParam{$_} = $ParamObject->GetParam(Param => $_);
    }

    my $ArticleID = $GetParam{ArticleID};

    if (!$Self->ArticleExist($ArticleID)) {
        $Output .= $LayoutObject->Error(
            Message => "Article doesn't exist: " . $ArticleID,
            Comment => 'tststs'
        );
        return ($Output);
    }

    my $TicketID = $ArticleObject->TicketIDLookup(
        ArticleID => $ArticleID
    );

    my $ArticleBackendObject = $ArticleObject->BackendForArticle(
        TicketID  => $TicketID,
        ArticleID => $ArticleID
    );

    foreach (qw(Subject From To Cc Body)) {
        if ( $GetParam{$_} && $GetParam{$_} ne '' ) {
            #Note: Key ``Body'', ``Subject'', ``From'', ``To'' and ``Cc'' is implemented.
            $ArticleBackendObject->ArticleUpdate(
                TicketID => $TicketID,
                ArticleID => $ArticleID,
                Key => $_,
                Value => $GetParam{$_},
                UserID => $Self->{UserID}
            );
            $LogObject->Log(
                Priority => 'notice',
                Message => "User " . $Self->{UserID} .
                    " changed \"$_\" from Article " . $GetParam{ArticleID}
            );
        }
    }

    if ($GetParam{AccountedTime} && isNumeric($GetParam{AccountedTime})) {
        $ArticleObject->ArticleAccountedTimeDelete(
            ArticleID => $ArticleID,
        );
        $TicketObject->TicketAccountTime(
            TicketID  => $TicketID,
            ArticleID => $ArticleID,
            TimeUnit  => $GetParam{AccountedTime},
            UserID    => $Self->{UserID}
        );
    }

    $Output .= $LayoutObject->Redirect(
        OP => "Action=SuperAdmin&Subaction=ArticleShow&ArticleID=" . $GetParam{ArticleID}
    );
    return($Output);
}

sub TicketExist {
    my $Self        = shift;
    my $TicketID    = shift;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my $TicketNumber = $TicketObject->TicketNumberLookup(
        TicketID => $TicketID,
        UserID => $Self->{UserID}
    );

    if ($TicketNumber > 0) {
        return(1);
    }

    return(0);
}

sub ArticleExist {
    my $Self = shift;
    my $ArticleID = shift;

    my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');

    if (isNumeric($ArticleID) && $ArticleObject->TicketIDLookup(ArticleID => $ArticleID)) {
        return(1);
    }
    return(0);
}

sub isSuperAdmin() {
    my $Self   = shift;

    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    return $GroupObject->PermissionCheck(
        UserID => $Self->{UserID},
        GroupName => '_SuperAdmin',
        Type => 'rw'
    );
}

# isCustomer
#
# return true if we are a customer user (in Customer Interface)
#
sub isCustomer() {
    my $Self = shift;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ($Self->{UserType} eq "User") {
        return(0);
    } elsif ($Self->{UserType} eq "Customer") {
        return(1);
    } else {
        $LogObject->Log(
            Priority => 'warning',
            Message => "WTF we arent User or Customer but " . $Self->{UserType} . ", aborting"
        );
        exit;
    }
}

sub isNumeric($) {
    my $s_input = shift;
    if ($s_input =~ /^-*\d+$/) {
        return (1);
    }
    return (0);
}
