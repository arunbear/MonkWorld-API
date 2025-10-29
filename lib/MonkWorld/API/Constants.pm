package MonkWorld::API::Constants;

use v5.40;
use Exporter 'import';

our @EXPORT_OK = qw(
    NODE_TYPE_NOTE
    NODE_TYPE_PERLQUESTION
);

use constant {
    NODE_TYPE_NOTE         => 11,
    NODE_TYPE_PERLQUESTION => 115,
};