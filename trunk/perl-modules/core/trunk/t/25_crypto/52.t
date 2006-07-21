use Test::More tests => 28;

print STDERR "OpenXPKI::Crypto::Secret\n";

use English;

BEGIN { use_ok( 'OpenXPKI::Crypto::Secret' ) }

# use Smart::Comments;

ok(1);

###########################################################################
# plain secrets
my $secret = OpenXPKI::Crypto::Secret->new();

ok(defined $secret);

ok(! $secret->is_complete());
ok(! defined $secret->get_secret());

ok($secret->set_secret('foobar'));

ok($secret->is_complete());
ok($secret->get_secret(), 'foobar');


# multi-part PINs
$secret = OpenXPKI::Crypto::Secret->new(
    {
	TYPE => 'Plain',
	PARTS => 3,
    });   # 'Plain' pin, three part

ok(! $secret->is_complete());
ok(! defined $secret->get_secret());

ok($secret->set_secret(
       {
	   PART => 1,
	   SECRET => 'foo',
       }));

ok($secret->set_secret(
       {
	   PART => 3,
	   SECRET => 'baz',
       }));
   
ok(! $secret->is_complete());
ok(! defined $secret->get_secret());

ok($secret->set_secret(
       {
	   PART => 2,
	   SECRET => 'bar',
       }));
   
ok($secret->is_complete());
ok($secret->get_secret(), 'foobarbaz');


###########################################################################
# split secrets

$secret = undef;
eval {
    $secret = OpenXPKI::Crypto::Secret->new(
	{
	    TYPE => 'Split',
	    QUORUM => 
	    {
		K => 3,
		N => 5,
	    },
	});   # 'Split' secret, 3 out of 5 shares
};

SKIP: {
     if ($EVAL_ERROR =~ m{ I18N_OPENXPKI_CRYPTO_SECRET_SPLIT_NOT_YET_IMPLEMENTED }xms) {
	 skip "Secret splitting not yet implemented", 11;
     }

    ok(defined $secret);
    
    my @shares = $secret->compute('foobarbaz');
    
    ok(! $secret->is_complete());
    ok(! defined $secret->get_secret());
    
    # share #2
    ok($secret->set_secret($shares[2]));
    
    ok(! $secret->is_complete());
    ok(! defined $secret->get_secret());
    

    # share #4
    ok($secret->set_secret($shares[4]));
    
    ok(! $secret->is_complete());
    ok(! defined $secret->get_secret());
    
    # share #1
    ok($secret->set_secret($shares[1]));
    
    ok($secret->is_complete());
    ok($secret->get_secret(), 'foobarbaz');
}