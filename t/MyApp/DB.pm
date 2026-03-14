# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package MyApp::DB;
use base 'Durance::DB';
use FindBin;

sub _build_dsn {"dbi:SQLite:dbname=$FindBin::Bin/var/test.db"};

1;
