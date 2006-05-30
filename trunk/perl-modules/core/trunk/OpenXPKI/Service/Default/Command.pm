## OpenXPKI::Service::Default::Command
##
## Written 2006 by Martin Bartosch for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision: 235 $
##

use strict;
use warnings;

package OpenXPKI::Service::Default::Command;
use English;

use Class::Std;

use OpenXPKI::Debug 'OpenXPKI::Service::Default::Command';
use OpenXPKI::Exception;
use OpenXPKI::Server::API;

my %command        : ATTR;
my %command_params : ATTR;

my %command_impl   : ATTR;
my %api            : ATTR( :get<API> );


# command registry
my %allowed_command = map { $_ => 1 } qw(
    nop

    get_ca_certificate
    list_ca_ids

    list_workflow_instances
    list_workflow_titles
);


sub BUILD {
    my ($self, $ident, $arg_ref) = @_;

    $command{$ident}        = $arg_ref->{COMMAND};
    $command_params{$ident} = $arg_ref->{PARAMS};
    $api{$ident}            = OpenXPKI::Server::API->new();
}

sub START {
    my ($self, $ident, $arg_ref) = @_;

    # only in Command.pm base class: get implementation
    if (ref $self eq 'OpenXPKI::Service::Default::Command') {
	$self->attach_impl($arg_ref);
    }
}



sub attach_impl : PRIVATE {
    my $self  = shift;
    my $arg   = shift;
    my $ident = ident $self;

    ##! 4: "attaching implementation"

    # command name
    my $cmd = $command{$ident};
    ##! 4: "command: $cmd"

    my $base = 'OpenXPKI::Service::Default::Command';

    if (defined $cmd && $allowed_command{$cmd}) {
	# command was white-listed and explicitly allowed
	
	my $class = $base . '::' . $cmd;
	##! 8: "loading class $class"
	eval "use $class;";
	if ($EVAL_ERROR) {
	    # expected error if no implementation is available. 
	    # We leave command_impl undefine to let execute() know
	    # that it should do automatic API mapping.

	    ##! 16: "$class does not seem to be available, falling back to default API mapping"
# 	    OpenXPKI::Exception->throw(
# 	        message => "I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_IMPL_LOAD_FAILED",
# 	        params  => {EVAL_ERROR => $EVAL_ERROR,
# 			    MODULE     => $class});
	} else {
	    ##! 8: "instantiating class $class"
	    $command_impl{$ident} = eval "$class->new()";

	    if ($EVAL_ERROR) {
		OpenXPKI::Exception->throw(
		    message => "I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_IMPL_INSTANTIATE_FAILED",
	            params  => {EVAL_ERROR => $EVAL_ERROR,
				MODULE     => $class});
	      }
	}
    } else {
	OpenXPKI::Exception->throw(
	    message => "I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_INVALID_COMMAND",
	);
    }
    
    return 1;
}


sub execute {
    my $self  = shift;
    my $arg   = shift;
    my $ident = ident $self;

    ##! 4: "execute: $command{$ident}"

    if (! defined $command_impl{$ident}) {
	my $method = $command{$ident};
	##! 8: "automatic API mapping for $method"

	return $self->command_response(
	    $self->get_API()->$method($arg),
	);
    } else {
	##! 16: "ref child: " . ref $command_impl{$ident}
	if (ref $command_impl{$ident}
	    eq 'OpenXPKI::Service::Default::Command::' . $command{$ident}) {
	    ##! 16: "implementation is present, delegating"
	    return $command_impl{$ident}->execute(
	        {
		    PARAMS => $command_params{$ident},
		});
	}
    }

    ##! 4: "FIXME: throw exception?"
    return {
	ERROR => "COMMAND EXECUTION METHOD NOT IMPLEMENTED",
    };
}


# convenience method to be called by command implementation
sub command_response {
    my $self  = shift;
    my $arg   = shift;
    my $ident = ident $self;

    my ($package, $filename, $line, $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(0);

    # only leave the last part of the package name
    my ($cmd) = ($package =~ m{ ([^:]+) \z }xms);

    return {
	SERVICE_MSG => 'COMMAND',
	COMMAND => $cmd,
	PARAMS  => $arg,
    };
}


1;

__END__

=head1 Description

Default service command base class. Handles command execution to
distinct command implementations.

=head1 Functions

=head2 START - new()

This class derives from Class::Std. Please read the corresponding 
documentation concerning BUILD, START construction methods and other
class-specific internals.

The new() constructor creates a new command object that is capable 
of executing the referenced interface command.
Expects the following named parameters:
  COMMAND => name of the command to execute
  PARAMS  => hash reference containing the command attributes

The constructor makes sure that only explicitly allowed commands are
accepted and throws an exception otherwise. If the constructor returns
without error (exception), the command was accepted as valid and the 
passed parameters have been stored internally to be processed later 
by the execute() method.

When attaching the implementation the class first try to 'use'
an actual Perl module which is named like the command. E. g.
if command 'foo' is requested, it tries to attach 
OpenXPKI::Service::Default::Command::foo.pm.
If no such module is available (but the command itself is whitelisted
to be available for use by the caller) the execute() method detects
that no explicit implementation is available and automatically
delegates the command call to the API.

=head2 execute

Executes the specified command implementation. Returns a data structure 
that can be serialized and directly returned to the client.

=head2 command_response

Returns a properly formatted command response (hash reference containing
the proper arguments). To be called by command implementations.
