use inc::Module::Install;

RTx 'RTx-REST';
all_from 'lib/RTx/REST.pm';
readme_from 'lib/RTx/REST.pm';
license  'gplv2';

requires_rt('4.1.17');

# 4.1.17 isn't quite enough; needs trs/4.2/rest-v2 for now.

requires 'Encode';
requires 'JSON';
requires 'Module::Pluggable' => '4.8';
requires 'Module::Runtime';
requires 'Moose';
requires 'MooseX::NonMoose';
requires 'namespace::autoclean';
requires 'Plack::Builder';
requires 'Scalar::Util';
requires 'Web::Machine' => '0.12';

sign;
WriteAll;
