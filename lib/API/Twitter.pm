# ABSTRACT: Perl 5 API wrapper for Twitter.com
package API::Twitter;

use API::Twitter::Class;

extends 'API::Twitter::Client';

use Carp ();
use Net::OAuth ();
use Scalar::Util ();

$Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A;

# VERSION

has access_token => (
    is       => 'rw',
    isa      => Str,
    required => 1,
);

has access_token_secret => (
    is       => 'rw',
    isa      => Str,
    required => 1,
);

has identifier => (
    is       => 'rw',
    isa      => Str,
    default  => 'API::Twitter (Perl)',
);

has consumer_key => (
    is       => 'rw',
    isa      => Str,
    required => 1,
);

has consumer_secret => (
    is       => 'rw',
    isa      => Str,
    required => 1,
);

has version => (
    is       => 'rw',
    isa      => Str,
    default  => '1.1',
);

method AUTOLOAD () {
    my ($package, $method) = our $AUTOLOAD =~ /^(.+)::(.+)$/;
    Carp::croak "Undefined subroutine &${package}::$method called"
        unless Scalar::Util::blessed $self && $self->isa(__PACKAGE__);

    # return new resource instance dynamically
    return $self->resource($method, @_);
}

method BUILD () {
    my $identifier = $self->identifier;
    my $version    = $self->version;
    my $agent      = $self->user_agent;
    my $url        = $self->url;

    $agent->transactor->name($identifier);

    $url->path("/$version");

    return $self;
}

method PREPARE ($ua, $tx, %args) {
    my $req     = $tx->req;
    my $headers = $req->headers;
    my $params  = $req->params->to_hash;
    my $url     = $req->url;

    # default headers
    $headers->header('Content-Type' => 'application/json');

    # append path suffix
    $url->path("@{[$url->path]}.json") if $url->path !~ /\.json$/;

    # oauth data
    my $consumer_key        = $self->consumer_key;
    my $consumer_secret     = $self->consumer_secret;
    my $access_token        = $self->access_token;
    my $access_token_secret = $self->access_token_secret;

    # oauth variables
    my $oauth_consumer_key     = $consumer_key;
    my $oauth_nonce            = Digest::SHA::sha1_base64(time . $$ . rand);
    my $oauth_signature_method = 'HMAC-SHA1',
    my $oauth_timestamp        = time,
    my $oauth_token            = $access_token,
    my $oauth_version          = '1.0';

    # oauth object
    my $base  = $url->clone; $base->query(undef);
    my $oauth = Net::OAuth->request('protected resource')->new(%$params,
        version          => '1.0',
        consumer_key     => $consumer_key,
        consumer_secret  => $consumer_secret,
        request_method   => uc($req->method),
        request_url      => $base,
        signature_method => 'HMAC-SHA1',
        timestamp        => time,
        token            => $access_token,
        token_secret     => $access_token_secret,
        nonce            => Digest::SHA::sha1_base64(time . $$ . rand),
    );
 
    $oauth->sign;

    # authorization header
    $headers->header('Authorization' => $oauth->to_authorization_header);
}

method action ($method, %args) {
    $method = uc($method || 'get');

    # execute transaction and return response
    return $self->$method(%args);
}

method create (%args) {
    # execute transaction and return response
    return $self->POST(%args);
}

method delete (%args) {
    # execute transaction and return response
    return $self->DELETE(%args);
}

method fetch (%args) {
    # execute transaction and return response
    return $self->GET(%args);
}

method resource (@segments) {
    # build new resource instance
    my $instance = __PACKAGE__->new(
        debug               => $self->debug,
        fatal               => $self->fatal,
        retries             => $self->retries,
        timeout             => $self->timeout,
        user_agent          => $self->user_agent,
        identifier          => $self->identifier,
        version             => $self->version,
        access_token        => $self->access_token,
        access_token_secret => $self->access_token_secret,
        consumer_key        => $self->consumer_key,
        consumer_secret     => $self->consumer_secret,
    );

    # resource locator
    my $url = $instance->url;

    # modify resource locator if possible
    $url->path(join '/', $self->url->path, @segments);

    # return resource instance
    return $instance;
}

method update (%args) {
    # execute transaction and return response
    return $self->PUT(%args);
}

1;

=encoding utf8

=head1 SYNOPSIS

    use API::Twitter;

    my $twitter = API::Twitter->new(
        consumer_key        => 'CONSUMER_KEY',
        consumer_secret     => 'CONSUMER_SECRET',
        access_token        => 'ACCESS_TOKEN',
        access_token_secret => 'ACCESS_TOKEN_SECRET',
        identifier          => 'IDENTIFIER',
    );

    $twitter->debug(1);
    $twitter->fatal(1);

    my $user = $twitter->users('lookup');
    my $results = $user->fetch;

    # after some introspection

    $user->update( ... );

=head1 DESCRIPTION

This distribution provides an object-oriented thin-client library for
interacting with the Twitter (L<http://twitter.com>) API. For usage and
documentation information visit L<https://dev.twitter.com/rest/public>.

=cut

=head1 THIN CLIENT

A thin-client library is advantageous as it has complete API coverage and
can easily adapt to changes in the API with minimal effort. As a thin-client
library, this module does not map specific HTTP requests to specific routines,
nor does it provide parameter validation, pagination, or other conventions
found in typical API client implementations, instead, it simply provides a
simple and consistent mechanism for dynamically generating HTTP requests.
Additionally, this module has support for debugging and retrying API calls as
well as throwing exceptions when 4xx and 5xx server response codes are
returned.

=cut

=head2 Building

    my $user = $twitter->users('lookup');

    $user->action; # GET   /users/lookup
    $user->action('head'); # HEAD  /users/lookup
    $user->action('patch'); # PATCH /users/lookup

Building up an HTTP request object is extremely easy, simply call method names
which correspond to the API's path segments in the resource you wish to execute
a request against. This module uses autoloading and returns a new instance with
each method call. The following is the equivalent:

=head2 Chaining

    my $users = $twitter->resource('users');

    # or

    my $users = $twitter->users;
    my $user  = $users->resource('lookup');

    # then

    $user->action('put', %args); # PUT /users/lookup

Because each call returns a new API instance configured with a resource locator
based on the supplied parameters, reuse and request isolation are made simple,
i.e., you will only need to configure the client once in your application.

=head2 Fetching

    my $users = $twitter->users;

    # query-string parameters

    $users->fetch( query => { ... } );

    # equivalent to

    my $users = $twitter->resource('users');

    $users->action( get => ( query => { ... } ) );

This example illustrates how you might fetch an API resource.

=head2 Creating

    my $users = $twitter->users;

    # content-body parameters

    $users->create( data => { ... } );

    # query-string parameters

    $users->create( query => { ... } );

    # equivalent to

    $twitter->resource('users')->action(
        post => ( query => { ... }, data => { ... } )
    );

This example illustrates how you might create a new API resource.

=head2 Updating

    my $users = $twitter->users;
    my $user  = $users->resource('lookup');

    # content-body parameters

    $user->update( data => { ... } );

    # query-string parameters

    $user->update( query => { ... } );

    # or

    my $user = $twitter->users('lookup');

    $user->update( ... );

    # equivalent to

    $twitter->resource('users')->action(
        put => ( query => { ... }, data => { ... } )
    );

This example illustrates how you might update a new API resource.

=head2 Deleting

    my $users = $twitter->users;
    my $user  = $users->resource('lookup');

    # content-body parameters

    $user->delete( data => { ... } );

    # query-string parameters

    $user->delete( query => { ... } );

    # or

    my $user = $twitter->users('lookup');

    $user->delete( ... );

    # equivalent to

    $twitter->resource('users')->action(
        delete => ( query => { ... }, data => { ... } )
    );

This example illustrates how you might delete an API resource.

=cut

=head2 Transacting

    my $users = $twitter->resource('users', 'lookup');

    my ($results, $transaction) = $users->action( ... );

    my $request  = $transaction->req;
    my $response = $transaction->res;

    my $headers;

    $headers = $request->headers;
    $headers = $response->headers;

    # etc

This example illustrates how you can access the transaction object used
represent and process the HTTP transaction.

=cut

=param access_token

    $twitter->access_token;
    $twitter->access_token('ACCESS_TOKEN');

The access_token parameter should be set to an API access_token associated with
your account.

=cut

=param access_token_secret

    $twitter->access_token_secret;
    $twitter->access_token_secret('ACCESS_TOKEN_SECRET');

The access_token_secret parameter should be set to an API access_token_secret
associated with your account.

=cut

=param consumer_key

    $twitter->consumer_key;
    $twitter->consumer_key('CONSUMER_KEY');

The consumer_key parameter should be set to an API consumer_key associated with
your account.

=cut

=param consumer_secret

    $twitter->consumer_secret;
    $twitter->consumer_secret('CONSUMER_SECRET');

The consumer_secret parameter should be set to an API consumer_secret
associated with your account.

=cut

=param identifier

    $twitter->identifier;
    $twitter->identifier('IDENTIFIER');

The identifier parameter should be set to a string that identifies your app.

=cut

=attr debug

    $twitter->debug;
    $twitter->debug(1);

The debug attribute if true prints HTTP requests and responses to standard out.

=cut

=attr fatal

    $twitter->fatal;
    $twitter->fatal(1);

The fatal attribute if true promotes 4xx and 5xx server response codes to
exceptions, a L<API::Twitter::Exception> object.

=cut

=attr retries

    $twitter->retries;
    $twitter->retries(10);

The retries attribute determines how many times an HTTP request should be
retried if a 4xx or 5xx response is received. This attribute defaults to 1.

=cut

=attr timeout

    $twitter->timeout;
    $twitter->timeout(5);

The timeout attribute determines how long an HTTP connection should be kept
alive. This attribute defaults to 10.

=cut

=attr url

    $twitter->url;
    $twitter->url(Mojo::URL->new('https://api.twitter.com'));

The url attribute set the base/pre-configured URL object that will be used in
all HTTP requests. This attribute expects a L<Mojo::URL> object.

=cut

=attr user_agent

    $twitter->user_agent;
    $twitter->user_agent(Mojo::UserAgent->new);

The user_agent attribute set the pre-configured UserAgent object that will be
used in all HTTP requests. This attribute expects a L<Mojo::UserAgent> object.

=cut

=method action

    my $result = $twitter->action($verb, %args);

    # e.g.

    $twitter->action('head', %args);    # HEAD request
    $twitter->action('options', %args); # OPTIONS request
    $twitter->action('patch', %args);   # PATCH request


The action method issues a request to the API resource represented by the
object. The first parameter will be used as the HTTP request method. The
arguments, expected to be a list of key/value pairs, will be included in the
request if the key is either C<data> or C<query>.

=cut

=method create

    my $results = $twitter->create(%args);

    # or

    $twitter->POST(%args);

The create method issues a C<POST> request to the API resource represented by
the object. The arguments, expected to be a list of key/value pairs, will be
included in the request if the key is either C<data> or C<query>.

=cut

=method delete

    my $results = $twitter->delete(%args);

    # or

    $twitter->DELETE(%args);

The delete method issues a C<DELETE> request to the API resource represented by
the object. The arguments, expected to be a list of key/value pairs, will be
included in the request if the key is either C<data> or C<query>.

=cut

=method fetch

    my $results = $twitter->fetch(%args);

    # or

    $twitter->GET(%args);

The fetch method issues a C<GET> request to the API resource represented by the
object. The arguments, expected to be a list of key/value pairs, will be
included in the request if the key is either C<data> or C<query>.

=cut

=method update

    my $results = $twitter->update(%args);

    # or

    $twitter->PUT(%args);

The update method issues a C<PUT> request to the API resource represented by
the object. The arguments, expected to be a list of key/value pairs, will be
included in the request if the key is either C<data> or C<query>.

=cut

=resource account

    $twitter->account;

The account method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#account>.

=cut

=resource application

    $twitter->application;

The application method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#application>.

=cut

=resource blocks

    $twitter->blocks;

The blocks method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#blocks>.

=cut

=resource direct_messages

    $twitter->direct_messages;

The direct_messages method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#direct_messages>.

=cut

=resource favorites

    $twitter->favorites;

The favorites method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#favorites>.

=cut

=resource followers

    $twitter->followers;

The followers method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#followers>.

=cut

=resource friends

    $twitter->friends;

The friends method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#friends>.

=cut

=resource friendships

    $twitter->friendships;

The friendships method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#friendships>.

=cut

=resource geo

    $twitter->geo;

The geo method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#geo>.

=cut

=resource help

    $twitter->help;

The help method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#help>.

=cut

=resource lists

    $twitter->lists;

The lists method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#lists>.

=cut

=resource media

    $twitter->media;

The media method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#media>.

=cut

=resource mutes

    $twitter->mutes;

The mutes method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#mutes>.

=cut

=resource saved_searches

    $twitter->saved_searches;

The saved_searches method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#saved_searches>.

=cut

=resource search

    $twitter->search;

The search method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#search>.

=cut

=resource statuses

    $twitter->statuses;

The statuses method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#statuses>.

=cut

=resource trends

    $twitter->trends;

The trends method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#trends>.

=cut

=resource users

    $twitter->users;

The users method returns a new instance representative of the API
resource requested. This method accepts a list of path segments which will be
used in the HTTP request. The following documentation can be used to find more
information. L<https://dev.twitter.com/rest/public#users>.

=cut

