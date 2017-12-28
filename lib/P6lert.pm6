unit class P6lert;
use JSON::Fast;
use P6lert::Alert;
use P6lert::Model::Alerts;
use Twitter;

has IO::Path:D $.db-file = 'alerts.sqlite.db'.IO;
has P6lert::Model::Alerts:D $.alerts = P6lert::Model::Alerts.new: :$!db-file;
has Str:D $.alert-url = 'https://alerts.perl6.org/alert';
has Str:D $.consumer-key        is required;
has Str:D $.consumer-secret     is required;
has Str:D $.access-token        is required;
has Str:D $.access-token-secret is required;
has Twitter:D $!twitter = Twitter.new: :$!consumer-key, :$!consumer-secret,
                                       :$!access-token, :$!access-token-secret;

method new {
    my %conf := from-json slurp $*PROGRAM.sibling: '../secret.json';
    %_{$_} //= %conf{$_} for <consumer-key  consumer-secret  access-token  access-token-secret>;
    self.bless: |%_
}

method add (
    Str:D  $alert-text,
    Str:D :$creator = 'Anonymous',
    Str:D :$affects = '',
    P6lert::Alert::Severity:D :$severity = 'normal',
    UInt:D :$time = time,
    Bool:D :$tweet = False,
) {
    my $id := $!alerts.add: $alert-text, :$creator, :$affects, :$severity, :$time;
    return $id unless $tweet;

    my $alert := $!alerts.get: $id;
    my $icon  := $alert.severity eq 'critical' ?? '⚠️' !! '';
    my $info  := "#p6lert ID $alert.id() | severity: $icon$alert.severity()$icon {
        "| affects: $alert.affects()" if $alert.affects
    } | posted by $alert.creator()\n\n";
    $!twitter.tweet: $info ~ (
        ($info ~ $alert.alert).chars < 280 ?? $alert.alert
            !! "$alert.alert-short() See: $!alert-url/$alert.id()"
    );
    $id
}