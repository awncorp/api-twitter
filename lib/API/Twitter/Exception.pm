# Twitter Next Exception Class
package API::Twitter::Exception;

use Data::Dumper ();
use Scalar::Util ();

use API::Twitter::Class;

use overload '""' => 'to_string', fallback => 1;

# VERSION

has ['code', 'method', 'res', 'url'] => (
    is => 'ro',
);

method caught ($e) {
    return ! Scalar::Util::blessed($e)
        && UNIVERSAL::isa($e, $self);
}

method dumper {
    local $Data::Dumper::Terse = 1;
    return Data::Dumper::Dumper($self);
}

method rethrow {
    die $self;
}

method throw ($class: %args) {
    die $class->new(%args,
        subroutine => (caller(1))[3],
        package    => (caller(0))[0],
        file       => (caller(0))[1],
        line       => (caller(0))[2],
    );
}

method to_string {
    return sprintf "%s response received while processing request %s %s\n",
        $self->code, $self->method, $self->url;
}

1;
