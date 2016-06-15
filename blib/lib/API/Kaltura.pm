package API::Kaltura;
use strict;
use warnings;
use XML::Twig;
use LWP;
use Carp;
use Data::Dumper;

BEGIN {
    our ($VERSION, %SESSION_TYPES, %MEDIA_TYPES, $CHUNK_SIZE);
    $VERSION     = '0.02EXPERIMENTAL';
    %SESSION_TYPES = (
        user => 0,
        admin => 2
    );
    %MEDIA_TYPES = (
        video => 1,
        image => 2,
        audio => 5,
        live_stream_flash => 201,
        live_stream_windows_media => 202,
        live_stream_real_media => 203,
        live_stream_quicktime => 204
    );
    # 10MB is a nice number...
    $CHUNK_SIZE = 10485760;
}

#### new
=head2 new

 Usage     : $KalturaAPIObj = KalturaAPI->new({
    secret => 'my secret',
    partnerId => 'my partner ID',
    sessionType => 'session type', # admin or user
    apiVersion => 3, # int
    kalturaUrl => 'https://my.kaltura.url'
 });
 Purpose   : Initializes KalturaAPI
 Returns   : KalturaAPI object
 Arguments  :  A hash of data, all gathered from your Kaltura instance,
 all required.
    Secret:  String containing a valid secret.
    partnerId:  Int partner id.
    sessonType:  String containing a session type.
        Currently only supports 'user' and 'admin'
    apiVersion:  Int api version.
    kalturaUrl:  String URL of your kaltura instance.

=cut

sub new {
    my ($class, $params) = @_;
    my $self = bless ({}, ref ($class) || $class);
    my @required = (
        'secret',
        'partnerId',
        'sessionType',
        'apiVersion',
        'kalturaUrl'
    );
    foreach my $requirement (@required) {
        if (!$params->{$requirement}) {
            croak("$requirement is required");
        } else {
            if ($requirement eq 'sessionType') {
                $self->{$requirement} = $API::Kaltura::SESSION_TYPES{lc($params->{$requirement})};
            } else {
                $self->{$requirement} = $params->{$requirement};
            }
        }
    }
    if ($params->{chunkSize}) {
        $API::Kaltura::CHUNK_SIZE = $params->{chunkSize};
    }

    $self->{format} = 'xml';
    return $self;
}
#### new end

#### runService
=head2 runService

 Usage     : $UAObj = $KalturaAPIObj->runService({param1 => 'param', paramN => paramN})
 Purpose   : Low level service request runner
 Returns   : LWP::UserAgent object.
 Argument  : A hash of parameters
 Comment   : This routine runs all requests internally, and is
            exposed for convenience and testing.  Parameters
            are dependent on what the end goal is for the request.
            A simple request would be to start a session:
                $uaObj = KalturaAPIObject->runService({
                    service => 'session',
                    action => 'start',
                    clientTag => 'testme'
                });
            To get the results, simply call the content method on
            the returned LWP::UserAgent object.
 See Also   : L<LWP::UserAgent>
=cut

sub runService {
    my ($self, $params) = @_;
    # merge in the necessary identification stuff...
    foreach my $required ('secret', 'partnerId') {
        $params->{$required} = $self->{$required};
    }
    if ($self->{current_ks}) {
        $params->{'ks'} = $self->{current_ks};
    }

    my $ua = LWP::UserAgent->new();
    push @{$ua->requests_redirectable}, 'POST';
    $ua->agent("KalturaAPI Perl Module");
    my $url = $self->{kalturaUrl} . '/api_v' . $self->{apiVersion};
    return $ua->post(
        $url,
        'Content-Type' => 'form-data',
        'Content' => $params
    );
}


#### runService end

#### startSession
=head2 startSession

 Usage     : $bool = $KalturaAPIObj->startSession();
 Purpose   : Initializes a Kaltura API session
 Returns   : bool
 Comment   : On success, sets the current_ks variable to the
            session that was returned.

=cut

sub startSession {
    my $self = shift;
    my $ua = $self->runService({
        service => 'session',
        action => 'start',
        type => $self->{sessionType}
    });
    my $result = __getResultFromReturn($ua);
    if ($result) {
        $self->{current_ks} = $result->text();
    } else {
        carp("No session supplied in result!");
        return 0;
    }
    return 1;
}
#### startSession end

#### endSession
=head2 endSession

 Usage     : $bool = $KalturaAPIObj->endSession();
 Purpose   : Destroys a Kaltura API session
 Returns   : bool

=cut

sub endSession {
    # this assumes a managed session.
    my $self = shift;
    my $uaObj = $self->runService({
        service => 'session',
        action => 'end',
        ks => $self->{current_ks}
    });
    $self->{current_ks} = '';
    return 1;
}
#### endSession end

#### getResult
=head2 getResult

 Usage     : $XMLTwigResultObject = $KalturaAPIObj->getResult(
                {param1 => 'param', paramN => paramN}
            );
 Purpose   : Service request runner
 Returns   : XML::Twig object
 Argument  : A hash of parameters
 Comment    This is a convenience method that executes runService(), and
            returns the "result" section of the returned XML object from
            Kaltura.
 See Also   : L<XML::Twig>
=cut

sub getResult {
    my ($self, $params) = @_;
    my $result = $self->runService($params);
    return __getResultFromReturn($result);
}
#### getResult end

#################### uploadFile ####################
=head2 uploadFile

 Usage     : $KalturaAPIObj->uploadFile(
                {param1 => 'param', paramN => paramN}
            );
 Purpose   : Service request runner
 Returns   : XML::Twig object or false on error.
 Argument  : A hash of parameters
 Comment   : uploading a file is an arduous task that requires multiple calls
            this is a convenience method to sidestep all of those.  This is
            considered experimental
 See Also   : L<XML::Twig>
=cut

# TODO:  Error catching.
sub uploadFile {
    my ($self, $params) = @_;
    if ($params->{categories} && $params->{categoriesIds}) {
        carp("Can't use both categories and categoriesIds");
        return 0;
    }

    if ($self->{sessionType} == $API::Kaltura::SESSION_TYPES{'user'}) {
        if ($params->{adminTags}) {
            carp("Not an admin session, ignoring adminTags.");
        }
    }

    my @file_data = stat($params->{file});
    my $upload_token_add_result = $self->getResult({
       service => 'uploadToken',
       action => 'add',
       'uploadToken:fileSize' => $file_data[7],
       'uploadToken:fileName' => $params->{file}
    });
    my $upload_token_id = $upload_token_add_result->first_child('id')->text();
    open(my $FH, '<', $params->{file});
    binmode $FH;
    my $last_location = 0;
    while (read($FH, my $buffer, $API::Kaltura::CHUNK_SIZE) != 0) {
        my $upload_params = {
            service => 'uploadToken',
            action => 'upload',
            uploadTokenId => $upload_token_id,
            fileData => [undef, $params->{file}, Content => $buffer],
        };

        if ($last_location != 0) {
            $upload_params->{'resume'} = 1;
            $upload_params->{'resumeAt'} = $last_location;
        }
        my $next_location = $last_location + $API::Kaltura::CHUNK_SIZE;
        if ($next_location >= $file_data[7]) {
            $upload_params->{finalChunk} = 1;
        } else {
            $upload_params->{finalChunk} = 0;
        }
        my $upload_token_upload_result = $self->getResult($upload_params);
        #TODO:  Catch for errors.
        $last_location = $next_location;
    }

    my $media_add_hash = {
        service => 'media',
        action => 'add',
        'entry:objectType' => 'KalturaMediaEntry',
        'entry:mediaType' => $API::Kaltura::MEDIA_TYPES{lc($params->{type})},
        'entry:categoriesIds' => $params->{categoriesIds},
        'entry:name' => $params->{name},
        'entry:description' => $params->{description},
        'entry:tags' => $params->{tags},
    };
    if ($params->{adminTags} && $self->{sessionType} == 2) {
        $media_add_hash->{'entry:adminTags'} = $params->{adminTags};
    }
    if ($params->{categories}) {
        $media_add_hash->{'entry:categories'} = $params->{categories};
    } elsif ($params->{categoriesIds}) {
        $media_add_hash->{'entry:categoriesIds'} = $params->{categoriesIds};
    }
    if ($params->{accessControlId}) {
        $media_add_hash->{'entry:accessControlId'} = $params->{accessControlId};
    }



    my $media_add_result = $self->getResult($media_add_hash);
    if($media_add_result->first_child('id')) {
        my $media_add_id = $media_add_result->first_child('id')->text();
        my $media_addContent_result = $self->getResult({
            service => 'media',
            action => 'addContent',
            entryId => $media_add_id,
            'resource:objectType' => 'KalturaUploadedFileTokenResource',
            'resource:token' => $upload_token_id
        });
        return $media_addContent_result;
    } else {
        carp("Media add failed!");
        carp($media_add_result->sprint);
        return 0;
    }

}
#### uploadFile end

#### Internal Methods
sub __getResultFromReturn {
    my $ua = shift;
    my $twig = XML::Twig->new('pretty_print' => 'indented');
    my $doc = $twig->safe_parse($ua->content());
    my $result = $doc->root->first_child('result');
    if ($result) {
        $doc->sprint;
        # check to see if the API barfed.
        if (my $error = $result->first_child('error')) {
            croak($error->sprint());
        } else {
            return $result;
        }
    } else {
        croak("Invalid content returned:  " . $ua->content);
        return 0;
    }
}

#################### main pod documentation begin ###################

=head1 NAME

KalturaAPI - Kaltura API utility.

=head1 SYNOPSIS

  use strict;
  use warnings;
  use KalturaAPI;
  my $kt = KalturaAPI->new({
    secret => 'my secret from Kaltura',
    kalturaUrl => 'https://my.kaltura.url',
    apiVersion => 3,
    sessionType => 'admin', # admin or user only
    partnerId => '1234567890'
  });

  $kt->startSession();

  # getResult will be the most commonly used function.
  #### get a user's KMS data.
  $userTwig = $kt->getResult({
    service => 'user',
    action => 'get',
    userId => 'someUserId'
  });

  # to get the raw L<LWP::UserAgent> object from Kaltura, you can use
  # runService.  This can be useful for troubleshooting problems.
  my $userUA = $kt->runService({
    service => 'user',
    action => 'get',
    userId => 'someUserId'
  });

  # Upload a file.  This is considered experimental as error catching
  # is not that great currently.
  my $upload_result = $kt->uploadFile({
    file => "/path/to/a/file",
    type => "audio", # see Kaltura API info for valid types.
    categoriesIds => '1234567890',
    name => 'Name for this media',
    description => 'Description for this media',
    tags => 'comma, separated, tags',
    adminTags => 'comma, separated, tags'
  });

  $kt->endSession();

=head1 DESCRIPTION

Easy low-level access to Kaltura API functions.

=head1 USAGE

Documentation for services and actions can be found on
Kaltura's website.  The simplest usage of this module is as
documented in the synopsis.

=head1 BUGS

Probably lots.  All undocumented.  May $DEITY have mercy upon you.

=head1 SUPPORT

For Kaltura, refer to your account rep or the Kaltura documentation and
forums.

For this module, please contact the author.

=head1 AUTHOR

    J. Eric Ellis
    CPAN ID: JELLISII
    jellisii@gmail.com

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

perl(1), L<XML::Twig>, L<LWP>, L<https://www.kaltura.com>.

=cut

1;
