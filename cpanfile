requires "Data::Object" => "0.20";
requires "Data::Object::Library" => "0.05";
requires "Data::Object::Signatures" => "0.03";
requires "Import::Into" => "1.002004";
requires "Mojolicious" => "6.08";
requires "Net::OAuth" => "0.28";
requires "perl" => "v5.14.2";

on 'test' => sub {
  requires "perl" => "v5.14.2";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};
