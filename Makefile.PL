use strict;
use warnings;
use inc::Module::Install;

name     'Daemon-Control-Plugin-HotStandby';
all_from 'lib/Daemon/Control/Plugin/HotStandby.pm';
author   q{Kiern Diment <zarquon@cpan.org>};
license  'artistic2';

tests_recursive('t');

resources (
   IRC        => 'irc://irc.perl.org/#web-simple',
   license    => 'http://www.perlfoundation.org/artistic_license_2_0',
   repository => 'git://github.com/Kiern Diment/Daemon-Control-Plugin-HotStandby.git',
   bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Daemon-Control-Plugin-HotStandby',
);

configure_requires (
   'Module::Install' => 0,
);

build_requires (
   'Test::More' => '0.88',
);

requires (
		  Daemon::Control => '0.001007',
		  Role::Tiny => 0,
		  Class::Method::Modifiers => 0,
);

install_as_cpan;
auto_install;
WriteAll;
