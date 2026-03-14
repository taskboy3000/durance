use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Durance',
    VERSION_FROM      => 'lib/Durance/Model.pm',
    AUTHOR            => 'Joe Johnston <jjohn@taskboy.com>',
    ABSTRACT          => 'Lightweight ActiveRecord-style ORM',
    LICENSE           => 'perl',
    PREREQ_PM         => {
        'Moo'          => 0,
        'DBI'          => 0,
        'DBD::SQLite'  => 0,
    },
    TEST_REQUIRES     => {
        'Test2::Suite' => 0,
    },
);
