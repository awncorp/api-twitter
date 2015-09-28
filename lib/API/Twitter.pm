# ABSTRACT: Twitter.com API Client
package API::Twitter;

use namespace::autoclean -except => 'has';

use Data::Object::Class;
use Data::Object::Class::Syntax;
use Data::Object::Signatures;

use Data::Object qw(load);
use Data::Object::Library qw(Str);
use Net::OAuth ();

extends 'API::Client';

# VERSION

our $DEFAULT_URL = "https://api.twitter.com";

$Net::OAuth::PROTOCOL_VERSION = Net::OAuth::PROTOCOL_VERSION_1_0A;

# VERSION

# ATTRIBUTES

has consumer_key        => rw;
has consumer_secret     => rw;
has access_token        => rw;
has access_token_secret => rw;
has oauth_type          => rw;

# CONSTRAINTS

req consumer_key        => Str;
req consumer_secret     => Str;
opt access_token        => Str;
opt access_token_secret => Str;
opt oauth_type          => Str;

# DEFAULTS

def identifier => 'API::Twitter (Perl)';
def oauth_type => 'protected resource';
def url        => method { load('Mojo::URL')->new($DEFAULT_URL) };
def version    => '1.1';

# CONSTRUCTION

after BUILD => method {
    my $identifier = $self->identifier;
    my $version    = $self->version;
    my $agent      = $self->user_agent;
    my $url        = $self->url;

    $agent->transactor->name($identifier);

    $url->path("/$version");

    return $self;
};

# METHODS

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
    my $oauth = Net::OAuth->request($self->oauth_type)->new(%$params,
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

    # oauth signature
    $oauth->sign;

    # authorization header
    $headers->header('Authorization' => $oauth->to_authorization_header);
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
API::Twitter is derived from L<API::Client> and inherits all of it's
functionality. Please read the documentation for API::Client for more
usage information.

=cut

=attr access_token

    $twitter->access_token;
    $twitter->access_token('ACCESS_TOKEN');

The access_token attribute should be set to an API access_token associated with
your account.

=cut

=attr access_token_secret

    $twitter->access_token_secret;
    $twitter->access_token_secret('ACCESS_TOKEN_SECRET');

The access_token_secret attribute should be set to an API access_token_secret
associated with your account.

=cut

=attr consumer_key

    $twitter->consumer_key;
    $twitter->consumer_key('CONSUMER_KEY');

The consumer_key attribute should be set to an API consumer_key associated with
your account.

=cut

=attr consumer_secret

    $twitter->consumer_secret;
    $twitter->consumer_secret('CONSUMER_SECRET');

The consumer_secret attribute should be set to an API consumer_secret
associated with your account.

=cut

=attr identifier

    $twitter->identifier;
    $twitter->identifier('IDENTIFIER');

The identifier attribute should be set to a string that identifies your app.

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
exceptions, a L<API::Client::Exception> object.

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
