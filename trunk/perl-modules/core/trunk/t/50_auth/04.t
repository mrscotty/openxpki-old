use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 7 };

print STDERR "OpenXPKI::Server::Authentication::Password\n";

use OpenXPKI::UI::Test;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Authentication;
ok(1);

## create context
use OpenXPKI::Server::Context qw( CTX );
### instantiating context...
ok(OpenXPKI::Server::Context::create(
       CONFIG => 't/config.xml',
       DEBUG  => 0,
   ));

## load authentication configuration
my $auth = OpenXPKI::Server::Authentication->new (
               DEBUG  => 0);
ok($auth);

## create new session
my $session = OpenXPKI::Server::Session->new (
                  DEBUG     => 0,
                  DIRECTORY => "t/50_auth/",
                  LIFETIME  => 5);
ok($session);

## set pki realm to identify configuration
$session->set_pki_realm ("Test Root CA");

## create new test user interface
my $gui = OpenXPKI::UI::Test->new({
              "DEBUG"                => 0,
              "AUTHENTICATION_STACK" => "User",
              "LOGIN"                => "John Doe",
              "PASSWD"               => "Doe"});
ok(OpenXPKI::Server::Context::setcontext ("gui" => $gui));

## perform authentication
ok($auth->login ({"SESSION" => $session}));

## check session
ok($session->is_valid());

1;