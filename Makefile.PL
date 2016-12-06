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

test_requires 'Try::Tiny';

my ($lp) = ($INC{'RT.pm'} =~ /^(.*)[\\\/]/);
my $lib_path = join( ' ', "$RT::LocalPath/lib", $lp );
my $sbin_path = $RT::SbinPath || "$RT::BasePath/sbin" || "/opt/rt3/sbin";
my $bin_path = $RT::BinPath || "$RT::BasePath/bin" || "/opt/rt3/bin";

substitute(
    {
        RT_LIB_PATH  => $lib_path,
        RT_BIN_PATH  => $bin_path,
        RT_SBIN_PATH => $sbin_path,
    },
    {
        sufix => '.in'
    },
    qw(t/lib/RT/Extension/REST2/Test.pm),
);

no_index package => 'RT::Extension::REST2::Test';

sign;
WriteAll;
