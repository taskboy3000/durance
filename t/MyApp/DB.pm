# All code copyright Joe Johnston <jjohn@taskboy.com> 2026
package MyApp::DB;
use Mojo::Base 'ORM::DB', '-signatures';
use FindBin;

has dsn => "dbi:SQLite2:dbname=$FindBin::Bin/var/test.db";

1;
