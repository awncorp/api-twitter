package API::Twitter::Class;

use Import::Into;

# VERSION

sub import {
    my $target = caller;

    Data::Object::Class->import::into($target);
    Data::Object::Signatures->import::into($target);
    Data::Object::Library->import::into($target => -types);

    return;
}

1;
