use inc::Module::Install;

RTx 'RT-Extension-REST2';
license  'gplv2';

githubmeta('github');

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
requires 'Web::Simple';
requires 'Class::Method::Modifiers';
requires 'Plack::Middleware::RequestHeaders';
requires 'Plack::Middleware::ReverseProxyPath';
requires 'Module::Path';
requires 'Pod::POM';

recommends 'JSON::XS';

sign;
WriteAll;
