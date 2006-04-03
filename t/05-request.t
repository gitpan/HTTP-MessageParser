#!perl

use strict;
use warnings;

use Test::More;

plan tests => 18;

use_ok( 'HTTP::MessageParser' );

my @good = (
    "GET / HTTP/1.1\x0D\x0A\x0D\x0A",
    [ 'GET', '/', 'HTTP/1.1', [], \'' ],
    'Request A',

    "GET /a/b/c/d HTTP/1.1\x0D\x0A\x0D\x0A",
    [ 'GET', '/a/b/c/d', 'HTTP/1.1', [], \'' ],
    'Request AA',

    "\x0D\x0AGET / HTTP/1.1\x0D\x0A\x0D\x0A",
    [ 'GET', '/', 'HTTP/1.1', [], \'' ],
    'Request B with leading empty line',

    "\x0D\x0A\x0D\x0AGET / HTTP/1.1\x0D\x0A\x0D\x0A",
    [ 'GET', '/', 'HTTP/1.1', [], \'' ],
    'Request C with leading empty lines',

    "GET / HTTP/1.1\x0D\x0A"
  . "Content-Length: 1000\x0D\x0A"
  . "\x0D\x0A",
    [ 'GET', '/', 'HTTP/1.1', [ 'content-length' => '1000' ], \'' ],
    'Request D with header',

    "GET / HTTP/1.1\x0D\x0A"
  . "Content-Length\x0D\x0A :\x0D\x0A 1000\x0D\x0A"
  . "\x0D\x0A",
    [ 'GET', '/', 'HTTP/1.1', [ 'content-length' => '1000' ], \'' ],
    'Request E with LWS before and after colon',

    "GET / HTTP/1.1\x0D\x0A"
  . "Content-Length\x0D\x0A : \x0D\x0A  1\x0D\x0A    0\x0D\x0A    0\x0D\x0A    0  \x0D\x0A"
  . "\x0D\x0A",
    [ 'GET', '/', 'HTTP/1.1', [ 'content-length' => '1 0 0 0' ], \'' ],
    'Request F with leading and trailing LWS and between field-content',

    "POST / HTTP/1.1\x0D\x0A\x0D\x0AMyBody",
    [ 'POST', '/', 'HTTP/1.1', [], \'MyBody' ],
    'Request G with body',

    "POST / HTTP/1.1\x0D\x0A"
  . "Content-Length: 6\x0D\x0A"
  . "\x0D\x0A"
  . "MyBody",
    [ 'POST', '/', 'HTTP/1.1', [ 'content-length' => '6' ], \'MyBody' ],
    'Request G with headers and body',

    "GET / HTTP/12.12\x0D\x0A\x0D\x0A",
    [ 'GET', '/', 'HTTP/12.12', [], \'' ],
    'Request H with future HTTP version',
);

while ( my ( $message, $expected, $test ) = splice( @good, 0, 3 ) ) {
    my $request = [ HTTP::MessageParser->parse_request(\$message) ];
    is_deeply $request, $expected, "Parsed $test";
}

my @bad = (
    "GET / HTTP/1.1\x0D\x0A",
    qr/^Bad Request/,
    'Request I missing end of the header fields CRLF',

    "GET / HTTP/1.1\x0A\x0A",
    qr/^Bad Request-Line/,
    'Request J only LF in request line',

    "G<E>T / HTTP/1.1\x0D\x0A\x0D\x0A",
    qr/^Bad Request-Line/,
    'Request K Method contains seperator chars',

    "GET / XXXX/1.1\x0D\x0A\x0D\x0A",
    qr/^Bad Request-Line/,
    'Request L Invalid HTTP version',

    "POST / HTTP/1.1\x0D\x0A"
  . "Content-Length: 6"
  . "\x0D\x0A"
  . "MyBody",
    qr/^Bad Request/,
    'Request M missing CRLF after header',

    "POST / HTTP/1.1\x0D\x0A"
  . "Content<->Length: 6\x0D\x0A"
  . "\x0D\x0A"
  . "MyBody",
    qr/^Bad Request/,
    'Request N invalid chars in field-name',

    "GET /sss/ /ss HTTP/1.1\x0D\x0A\x0D\x0A",
    qr/^Bad Request-Line/,
    'Request O Invalid LWS in uri',
);

while ( my ( $message, $expected, $test ) = splice( @bad, 0, 3 ) ) {
    eval { HTTP::MessageParser->parse_request(\$message) };
    like $@, $expected, "Failed $test";
}
