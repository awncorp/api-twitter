requires "API::Client" => "0.01";
requires "Data::Object" => "0.55";
requires "Mojolicious" => "6.22";
requires "Net::OAuth" => "0.28";
requires "namespace::autoclean" => "0.27";
requires "perl" => "v5.14.0";

on 'test' => sub {
  requires "perl" => "v5.14.0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};
