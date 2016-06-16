package API::Kaltura;
use strict;
use warnings;
use XML::Twig;
use LWP;
use Carp;
use Data::Dumper;

BEGIN {
    our ( $VERSION, %SESSION_TYPES, %MEDIA_TYPES, $CHUNK_SIZE );
    $VERSION       = '0.02EXPERIMENTAL';
    %SESSION_TYPES = (
        user  => 0,
        admin => 2
    );
    %MEDIA_TYPES = (
        video                     => 1,
        image                     => 2,
        audio                     => 5,
        live_stream_flash         => 201,
        live_stream_windows_media => 202,
        live_stream_real_media    => 203,
        live_stream_quicktime     => 204,
    );

    # 10MB is a nice number...
    $CHUNK_SIZE = '10485760';
}

sub new {
    my ( $class, $params ) = @_;
    my $self = bless {}, ref($class) || $class;
    my @required = qw(
      secret
      partnerId
      sessionType
      apiVersion
      kalturaUrl
    );

    foreach my $requirement (@required) {
        if ( !$params->{$requirement} ) {
            croak("$requirement is required");
        }
        else {
            if ( $requirement eq 'sessionType' ) {
                $self->{$requirement} =
                  $API::Kaltura::SESSION_TYPES{ lc( $params->{$requirement} ) };
            }
            else {
                $self->{$requirement} = $params->{$requirement};
            }
        }
    }
    if ( $params->{chunkSize} ) {
        $API::Kaltura::CHUNK_SIZE = $params->{chunkSize};
    }

    $self->{format} = 'xml';
    return $self;
}

sub run_service {
    my ( $self, $params ) = @_;

    # merge in the necessary identification stuff...
    foreach my $required ( 'secret', 'partnerId' ) {
        $params->{$required} = $self->{$required};
    }
    if ( $self->{current_ks} ) {
        $params->{'ks'} = $self->{current_ks};
    }

    my $ua = LWP::UserAgent->new();
    push @{ $ua->requests_redirectable }, 'POST';
    $ua->agent('KalturaAPI Perl Module');
    my $url = $self->{kalturaUrl} . '/api_v' . $self->{apiVersion};
    return $ua->post(
        $url,
        'Content-Type' => 'form-data',
        'Content'      => $params
    );
}

sub start_session {
    my $self = shift;
    my $ua   = $self->run_service(
        {
            service => 'session',
            action  => 'start',
            type    => $self->{sessionType}
        }
    );
    my $result = __get_result_from_return($ua);
    if ($result) {
        $self->{current_ks} = $result->text();
    }
    else {
        carp('No session supplied in result!');
        return 0;
    }
    return 1;
}

sub end_session {

    # this assumes a managed session.
    my $self  = shift;
    my $uaobj = $self->run_service(
        {
            service => 'session',
            action  => 'end',
            ks      => $self->{current_ks}
        }
    );
    undef $self->{current_ks};
    return 1;
}

sub get_result {
    my ( $self, $params ) = @_;
    my $result = $self->run_service($params);
    return $self->__get_result_from_return($result);
}

# TODO:  Error catching.
sub upload_file {
    my ( $self, $params ) = @_;
    if ( $params->{categories} && $params->{categoriesIds} ) {
        carp('Can\'t use both categories and categoriesIds');
        return 0;
    }

    if ( $self->{sessionType} == $API::Kaltura::SESSION_TYPES{'user'} ) {
        if ( $params->{adminTags} ) {
            carp('Not an admin session, ignoring adminTags.');
        }
    }

    my @file_data               = stat( $params->{file} );
    my $upload_token_add_result = $self->getResult(
        {
            service                => 'uploadToken',
            action                 => 'add',
            'uploadToken:fileSize' => $file_data['7'],
            'uploadToken:fileName' => $params->{file}
        }
    );
    my $upload_token_id = $upload_token_add_result->first_child('id')->text();
    open my $FH, '<', $params->{file}
      or croak("Could not read $params->{file}");
    binmode $FH;
    $self->__upload_process( $FH, $upload_token_id, $params, @file_data );
    close $FH or croak("Cculd not close $params->{file}");

    my $media_add_hash = {
        service            => 'media',
        action             => 'add',
        'entry:objectType' => 'KalturaMediaEntry',
        'entry:mediaType' =>
          $API::Kaltura::MEDIA_TYPES{ lc( $params->{type} ) },
        'entry:categoriesIds' => $params->{categoriesIds},
        'entry:name'          => $params->{name},
        'entry:description'   => $params->{description},
        'entry:tags'          => $params->{tags},
    };

    if ( $params->{adminTags} && $self->{sessionType} == 2 ) {
        $media_add_hash->{'entry:adminTags'} = $params->{adminTags};
    }
    if ( $params->{categories} ) {
        $media_add_hash->{'entry:categories'} = $params->{categories};
    }
    elsif ( $params->{categoriesIds} ) {
        $media_add_hash->{'entry:categoriesIds'} = $params->{categoriesIds};
    }
    if ( $params->{accessControlId} ) {
        $media_add_hash->{'entry:accessControlId'} = $params->{accessControlId};
    }

    my $media_add_result = $self->getResult($media_add_hash);
    if ( $media_add_result->first_child('id') ) {
        my $media_add_id = $media_add_result->first_child('id')->text();
        my $media_add_content_result = $self->getResult(
            {
                service               => 'media',
                action                => 'addContent',
                entryId               => $media_add_id,
                'resource:objectType' => 'KalturaUploadedFileTokenResource',
                'resource:token'      => $upload_token_id
            }
        );
        return $media_add_content_result;
    }
    else {
        carp('Media add failed!');
        carp( $media_add_result->sprint );
        return 0;
    }

}

sub __upload_process {
    my ( $self, $FH, $upload_token_id, $params, @file_data ) = @_;
    my $last_location = 0;
    while ( read( $FH, my $buffer, $API::Kaltura::CHUNK_SIZE ) != 0 ) {
        my $upload_params = {
            service       => 'uploadToken',
            action        => 'upload',
            uploadTokenId => $upload_token_id,
            fileData      => [ undef, $params->{file}, Content => $buffer ],
        };

        if ( $last_location != 0 ) {
            $upload_params->{'resume'}   = 1;
            $upload_params->{'resumeAt'} = $last_location;
        }
        my $next_location = $last_location + $API::Kaltura::CHUNK_SIZE;
        if ( $next_location >= $file_data['7'] ) {
            $upload_params->{finalChunk} = 1;
        }
        else {
            $upload_params->{finalChunk} = 0;
        }
        my $upload_token_upload_result = $self->getResult($upload_params);

        #TODO:  Catch for errors.
        $last_location = $next_location;
    }
    return 1;
}

sub __get_result_from_return {
    my ($self, $ua) = @_;
    my $twig        = XML::Twig->new( 'pretty_print' => 'indented' );
    my $doc         = $twig->safe_parse( $ua->content() );
    my $result      = $doc->root->first_child('result');
    if ($result) {
        $doc->sprint;

        # check to see if the API barfed.
        if ( my $error = $result->first_child('error') ) {
            croak( $error->sprint() );
        }
        else {
            return $result;
        }
    }
    else {
        carp("Invalid content returned: $ua->content");
        return 0;
    }
}

1;

__END__

#################### main pod documentation begin ###################

=head1 NAME

API::Kaltura - Kaltura API utility.

=head1 VERSION

0.03

=head1 SYNOPSIS

    use API::Kaltura;
    my $kt = API::Kaltura->new({
        secret => 'my secret from Kaltura',
        kalturaUrl => 'https://my.kaltura.url',
        apiVersion => 3,
        sessionType => 'admin', # admin or user only
        partnerId => '1234567890'
    });
    $kt->start_session();
    
    # getResult will be the most commonly used function.
    # get a user's KMS data.
    $user_twig = $kt->get_result({
        service => 'user',
        action => 'get',
        userId => 'someUserId'
    });
    
    # To get the raw L<LWP::UserAgent|LWP::UserAgent> object from Kaltura, you 
    # can use run_service.  This can be useful for troubleshooting problems.
    my $ua = $kt->run_service({
        service => 'user',
        action => 'get',
        userId => 'someUserId'
    });
    
    # Upload a file.  This is considered experimental as error catching
    # is not that great currently.
    my $upload_result = $kt->upload_file({
        file => "/path/to/a/file",
        type => "audio", # see Kaltura API info for valid types.
        categoriesIds => '1234567890',
        name => 'Name for this media',
        description => 'Description for this media',
        tags => 'comma, separated, tags',
        adminTags => 'comma, separated, tags'
    });
    
    # Kill the existing session.
    $kt->endSession();

=head1 DESCRIPTION

Easy low-level access to Kaltura API functions.

=head1 USAGE

Documentation for services and actions can be found on Kaltura's website.
The simplest usage of this module is as documented in the synopsis.

=head1 SUBROUTINES/METHODS

=head2 $kt = API::Kaltura->new($hashref)

Bootstraps a new instance of API::Kaltura.  The following are all
required.

=over 4

=item secret

A secret.  This is provided by your KMC/Kaltura.    

=item kalturaUrl

The URL of your Kaltura instance.

=item apiVersion

Version of the API to use.  As of this writing, only 3 is supported.

=item sessionType

Kaltura session type.  As of this writing, admin or user are the only
supported session types.

=item partnerId

Partner ID.  This is provided by your KMC/Kaltura.

=back

=head2 $kt->start_session()

Starts a Kaltura Session.  Returns true if successful.

Currently, session lengths are defined by the server.  There is a TODO to
be able to pass a session length with this method.

=head2 $kt->get_result($hashref)

Gets the results of a specified request.  Returns an XML::Twig object. The
following are required:

=over 4

=item service

The service to be used.

=item action

The action on the service.

=back

Most actions have other requirements as well.  See the Kaltura API
documentation for more details

=head2 $kt->run_service($hashref)

This method has the same requirements as get_result.  The only difference
is that it returns a LWP object.  This method is envisioned to primarily
be used for troubleshooting API access.

=head2 $kt->upload_file($hashref)

B<This method is considered experimental.  It probably will change.>

This method wraps up all the calls required to upload a file into the
Kaltura instance.  Returns an XML::Twig object.  The following are required.

=over 4

=item file

A file to be uploaded.  This should be something media-ish, but Kaltura
will ingest almost anything.  

=back

=head2 $kt->end_session()

Kills the existing session being used by the API::Kaltura object.  

=head1 DEPENDENCIES

L<XML::Twig|XML::Twig>, L<LWP|LWP>

=head1 BUGS AND LIMITATIONS

Probably lots.  All undocumented.  May $DEITY have mercy upon you.

This API is woefully incomplete when compared to the other options that
are available from Kaltura.  

=head1 SUPPORT

For Kaltura, refer to your account rep or the Kaltura documentation and
forums.
For this module, please contact the author.

=head1 AUTHOR

J. Eric Ellis

CPAN ID: JELLISII

jellisii@gmail.com

=head1 LICENSE AND COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.
The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

perl(1), L<XML::Twig|XML::Twig>, L<LWP|LWP>,
L<www.kaltura.com|https://www.kaltura.com>
