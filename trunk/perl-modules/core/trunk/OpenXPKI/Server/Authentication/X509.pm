## OpenXPKI::Server::Authentication::X509.pm 
##
## Written 2006 by Michael Bell
## Rewritten 2007 by Alexander Klink for the OpenXPKI Project
## (C) Copyright 2006, 2007 by The OpenXPKI Project
## $Revision$
package OpenXPKI::Server::Authentication::X509;

use strict;
use warnings;
use English;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use MIME::Base64;

use Data::Dumper;

## constructor and destructor stuff

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = shift;
    ##! 1: "start"

    my $config = CTX('xml_config');

    $self->{DESC} = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "description" ],
                                        COUNTER => [ @{$keys->{COUNTER}}, 0 ],
                                        CONFIG_ID => $keys->{CONFIG_ID},
    );
    $self->{NAME} = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "name" ],
                                        COUNTER => [ @{$keys->{COUNTER}}, 0 ],
                                        CONFIG_ID => $keys->{CONFIG_ID},
    );

    # create an empty arrayref of pending challenges
    $self->{PENDING_CHALLENGES} = [];

    my $trust_anchors;
    my @trust_anchors;
    eval {
        $trust_anchors = $config->get_xpath(
            XPATH    => [ @{$keys->{XPATH}},   "trust_anchors" ],
            COUNTER  => [ @{$keys->{COUNTER}}, 0 ],
            CONFIG_ID => $keys->{CONFIG_ID},
        );
        @trust_anchors = split(q{,}, $trust_anchors);
    };
    if (! scalar @trust_anchors || $EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_MISSING_TRUST_ANCHOR_CONFIGURATION',
            params  => {
                TRUST_ANCHORS => $trust_anchors,
                EVAL_ERROR    => $EVAL_ERROR,
            },
        );
    }
    $self->{TRUST_ANCHORS} = \@trust_anchors;
    eval {
        $self->{PKCS7TOOL} = $config->get_xpath(
            XPATH    => [ @{$keys->{XPATH}},   "pkcs7tool" ],
            COUNTER  => [ @{$keys->{COUNTER}}, 0 ],
            CONFIG_ID => $keys->{CONFIG_ID},
        );
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_MISSING_PKCS7TOOL_CONFIGURATION',
            params  => {
                EVAL_ERROR    => $EVAL_ERROR,
            },
        );
    }
    eval {
        $self->{CHALLENGE_LENGTH} = $config->get_xpath(
            XPATH     => [ @{$keys->{XPATH}},   "challenge_length" ],
            COUNTER   => [ @{$keys->{COUNTER}}, 0 ],
            CONFIG_ID => $keys->{CONFIG_ID},
        );
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_MISSING_CHALLENGE_LENGTH_CONFIGURATION',
            params  => {
                EVAL_ERROR    => $EVAL_ERROR,
            },
        );
    }

    return $self;
}

sub login_step {
    ##! 1: 'start' 
    my $self    = shift;
    my $arg_ref = shift;
 
    my $name    = $arg_ref->{HANDLER};
    my $msg     = $arg_ref->{MESSAGE};

    if (! exists $msg->{PARAMS}->{CHALLENGE} ||
        ! exists $msg->{PARAMS}->{SIGNATURE}) {
        ##! 4: 'no login data received (yet)' 
        # get a random challenge
        my $random_data = CTX('api')->get_random({
            LENGTH => $self->{CHALLENGE_LENGTH},
        });
        my $challenge = encode_base64($random_data);
        $challenge =~ s/\n//g;
        ##! 64: 'challenge: ' . $challenge
        # save the pending challenge to check later that we
        # received a valid challenge
        push @{ $self->{PENDING_CHALLENGES} }, $challenge;
        ##! 64: 'pending challenges: ' . Dumper $self->{PENDING_CHALLENGES}

        return (undef, undef, 
            {
		SERVICE_MSG => "GET_X509_LOGIN",
		PARAMS      => {
                    NAME        => $self->{NAME},
                    DESCRIPTION => $self->{DESC},
                    CHALLENGE   => $challenge,
	        },
            },
        );
    }
    else {
        ##! 2: 'login data / signature received'
        my $challenge = $msg->{PARAMS}->{CHALLENGE};
        my $signature = $msg->{PARAMS}->{SIGNATURE};
        my $pki_realm = CTX('session')->get_pki_realm();

        if ($signature !~ m{ \A .* \n \z }xms) {
            # signature does not end with \n, add it
            $signature .= "\n";
        }
        ##! 64: 'challenge: ' . $challenge
        ##! 64: 'signature: ' . $signature
        ##! 64: 'pending challenges: ' . Dumper $self->{PENDING_CHALLENGES}

        if (! grep { $_ eq $challenge } @{$self->{PENDING_CHALLENGES}}) {
            # the sent challenge is not a pending one
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_CHALLENGE_IS_NOT_PENDING',
                params  => {
                    CHALLENGE => $challenge,
                },
            );
        }
        if (! $signature =~ m{ \A [a-zA-Z\+/=]+ \z }xms) {
            # the sent signature is not in Base64 format
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_SIGNATURE_IS_NOT_BASE64',
            );
        }
        my $tm = CTX('crypto_layer');
        my $pkcs7 =
              '-----BEGIN PKCS7-----' . "\n"
            . $signature
            . '-----END PKCS7-----';
        my $pkcs7_token = $tm->get_token(
            TYPE      => 'PKCS7',
            ID        => $self->{PKCS7TOOL},
            PKI_REALM => $pki_realm,
        );
        eval {
            $pkcs7_token->command({
                COMMAND => 'verify',
                PKCS7   => $pkcs7,
                DATA    => $challenge,
            });
        };
        if ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_INVALID_SIGNATURE',
            );
        }
        ##! 16: 'signature valid'
        my $signer_subject;
        eval {
            $signer_subject = $pkcs7_token->command({
                COMMAND => 'get_subject',
                PKCS7   => $pkcs7,
                DATA    => $challenge,
            });
        };
        if ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_COULD_NOT_DETERMINE_SIGNER_SUBJECT',
            );
        }
        ##! 16: 'signer subject: ' . $signer_subject
        my $default_token = CTX('pki_realm')->{$pki_realm}->{crypto}->{default};
        my @signer_chain = $default_token->command({
            COMMAND        => 'pkcs7_get_chain',
            PKCS7          => $pkcs7,
            SIGNER_SUBJECT => $signer_subject,
        });
        ##! 64: 'signer_chain: ' . Dumper \@signer_chain

        my $sig_identifier = OpenXPKI::Crypto::X509->new(
            TOKEN => $default_token,
            DATA  => $signer_chain[0],
        )->get_identifier();
        if (! defined $sig_identifier || $sig_identifier eq '') {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_COULD_NOT_DETERMINE_SIGNATURE_CERTIFICATE_IDENTIFIER',
            );
        }
        ##! 64: 'sig identifier: ' . $sig_identifier

        my @signer_chain_server;
        eval {
            @signer_chain_server = @{ CTX('api')->get_chain({
                START_IDENTIFIER => $sig_identifier,
            })->{IDENTIFIERS} };
        };
        if ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_COULD_NOT_DETERMINE_SIGNATURE_CHAIN_FROM_SERVER',
                params  => {
                    EVAL_ERROR => $EVAL_ERROR,
                },
            );
        }
        ##! 64: 'signer_chain_server: ' . Dumper \@signer_chain_server
        my $anchor_found;
        my @trust_anchors = @{ $self->{TRUST_ANCHORS} };
      CHECK_CHAIN:
        foreach my $identifier (@signer_chain_server) {
            ##! 16: 'identifier: ' . $identifier
            if (grep {$identifier eq $_} @trust_anchors) {
                $anchor_found = 1;
                last CHECK_CHAIN;
            }
        }
        if (! defined $anchor_found) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_UNTRUSTED_CERTIFICATE',
                params  => {
                    'IDENTIFIER' => $sig_identifier,
                },
            );
        }

        # Get the signer cert from the DB (and check that it is valid now)
        my $cert_db = CTX('dbi_backend')->first(
            TABLE    => 'CERTIFICATE',
            DYNAMIC  => {
                'IDENTIFIER' => $sig_identifier,
                'STATUS'     => 'ISSUED',
            },
            VALID_AT => time(),
        );
        if (! defined $cert_db) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_CERT_NOT_FOUND_IN_DB_OR_INVALID',
                params  => {
                    'IDENTIFIER' => $sig_identifier,
                },
            );
        } 
        my $user = $signer_subject;
        my $role = $cert_db->{ROLE};
        return ($user, $role,
            {
                SERVICE_MSG => 'SERVICE_READY',
            },
        ); 
    }
    return (undef, undef, {});
}

1;
__END__

=head1 Name

OpenXPKI::Server::Authentication::X509 - certificate based authentication.

=head1 Description

This is the class which supports OpenXPKI with a signature based
authentication method. The parameters are passed as a hash reference.

=head1 Functions

=head2 new

is the constructor. The supported parameters are XPATH and COUNTER.
This is the minimum parameter set for any authentication class.
The parameters which are taken from the configuration are trust_anchors
and pkcs7tool, which works in the same way as in the approval signature
case. Furthermore, the challenge_length is taken to define the length
(in bytes) of the random challenge that is being created.

=head2 login_step

returns a pair of (user, role, response_message) for a given login
step. If user and role are undefined, the login is not yet finished.
