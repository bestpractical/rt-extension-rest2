use inc::Module::Install;

RTx 'RT-Extension-REST2';
all_from 'lib/RT/Extension/REST2.pm';
readme_from 'lib/RT/Extension/REST2.pm';
license  'gplv2';

requires_rt('4.2.4');

requires 'Encode';
requires 'JSON';
requires 'Module::Runtime';
requires 'Moose';
requires 'MooseX::NonMoose';
requires 'MooseX::Role::Parameterized';
requires 'namespace::autoclean';
requires 'Plack::Builder';
requires 'Scalar::Util';
requires 'Sub::Exporter';
requires 'Web::Machine' => '0.12';
requires 'Class::Method::Modifiers';

sign;
WriteAll;
