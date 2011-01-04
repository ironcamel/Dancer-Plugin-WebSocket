use Test::More import => ['!pass'], tests => 6;

BEGIN {
    use_ok 'Dancer::Plugin::WebSocket';
    use_ok 'AnyMQ';
    use_ok 'Plack';
    use_ok 'Web::Hippie';
}

my $topic = Dancer::Plugin::WebSocket::_topic();
my $listener = AnyMQ->new_listener($topic);

websocket_send 'allo';

$listener->poll_once(sub {
    my @msgs = @_;
    is @msgs => 1, "got one websocket message";
    is_deeply $msgs[0] => { msg => 'allo' }, "got the right websocket message";
});

done_testing;
