package Dancer::Plugin::WebSocket;
use Carp;
use Dancer ':syntax';

# VERSION

use AnyMQ;
use Dancer::Plugin;
use Plack;
use Web::Hippie;
use Carp;

my $bus;
sub _bus {
    return $bus if $bus;
    return $bus = AnyMQ->new;
}

my $topic;
sub _topic {
    return $topic if $topic;
    return $topic = _bus->topic('dancer-plugin-websocket');
}

my $triggers = {};

set plack_middlewares_map => {
    '/_hippie' => [
        [ '+Web::Hippie' ],
        [ '+Web::Hippie::Pipe', bus => _bus ],
    ]
};

# Web::Hippie routes
get '/new_listener' => sub {

    if (defined $triggers->{on_new_listener}) {
        $triggers->{on_new_listener}->();
    }

    request->env->{'hippie.listener'}->subscribe(_topic);
};

get '/message' => sub {
    my $msg = request->env->{'hippie.message'};

    if ( defined $triggers->{on_message} ) {
        $msg = $triggers->{on_message}->($msg);
    }
    _topic->publish($msg);
};

my $ws_send = sub {
    my $msg = shift;
    _topic->publish({ msg => $msg });
};

register ws_on_message => sub {
    $triggers->{on_message} = shift;
};

register ws_on_new_listener => sub {
    $triggers->{on_new_listener} = shift;
};

register ws_send => sub {
    $ws_send->(@_);
};

register websocket_send => sub {
    carp "'websocket_send' is deprecated. You should use 'ws_send' instead.";
    $ws_send->(@_);
};

register_plugin;

# ABSTRACT: A Dancer plugin for easily creating WebSocket apps

=head1 SYNOPSIS

    # ./bin/app.pl
    use Dancer;
    use Dancer::Plugin::WebSocket;

    get '/' => sub { template 'index' };

    ws_on_message sub {
        my $message = shift;
        if ($message->{hello}) {
            debug("got hello");
        }
    };

    # an API method to broadcast a message to all listeners
    any '/send_msg' => sub {
        my $msg = params->{msg};
        ws_send($msg);
        return "sent $msg\n";
    };

    dance;

    # ./views/index.tt
    <html>
    <head>
    <script src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"></script>
    <script>
    var socket;
    $(function() {
        // ws_path should be of the form ws://host/_hippie/ws
        var ws_path = "ws:<% request.base.opaque %>_hippie/ws";
        socket = new WebSocket(ws_path);
        socket.onopen = function() {
            $('#connection-status').text("Connected");
        };
        socket.onmessage = function(e) {
            var data = JSON.parse(e.data);
            if (data.msg)
                alert (data.msg);
        };
    });
    function send_msg(message) {
        socket.send(JSON.stringify({ msg: message }));
    }
    </script>
    </head>
    <body>
    Connection Status: <span id="connection-status"> Disconnected </span>
    <input value="Send Message" type=button onclick="send_msg('hello')" />
    </body>
    </html>

    # Run app with Twiggy
    plackup -s Twiggy bin/app.pl

    # Visit http://localhost:5000 and click the button or interact via curl:
    curl http://localhost:5000/send_msg?msg=hello

=head1 DESCRIPTION

This plugin provides the keywords ws_send, which takes 1 argument,
the message to send to the websocket.

This plugin is built on top of L<Web::Hippie>, but it abstracts that out for you.

You should be aware that it registers 2 routes that Web::Hippie needs: get('/new_listener') and get('/message').

Be careful to not define those routes in your app.

This requires that you have L<Plack> and L<Web::Hippie> installed.

It also requires that you run your app via L<Twiggy>.
For example:

    plackup -s Twiggy bin/app.pl

=head1 METHODS

=head2 ws_on_message ($message)

    ws_on_message sub {
        my $msg = shift;
        # do something with $msg
    }

=head2 ws_on_new_listener

    ws_on_new_listener sub {
        # do something when a new listener arrives
    };

=head2 ws_send ($message)

    get '/broadcast' => sub {
        my $msg = params->{msg};
        ws_send($msg);
    };

=cut

1;
