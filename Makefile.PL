use inc::Module::Install;

name            'Object-Closures';
license         'perl';
all_from        'lib/Object/Closures.pm';

requires        'Clone::Closure'    => '0.01';
build_requires  'Test::More'        => '0.68';

WriteAll;
